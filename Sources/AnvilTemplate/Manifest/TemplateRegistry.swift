import Foundation

/// Errors that can occur during registry operations.
public enum TemplateRegistryError: Error, Sendable, Equatable {
    case invalidRegistryVersion(expected: Int, actual: Int)
    case templateNotFound(String)
    case networkFailure(String)
    case invalidRegistryData(String)
    case cacheFailure(String)
}

/// A source reference for a template (e.g., git repo + tag).
public struct TemplateSource: Sendable, Codable, Equatable {
    public let type: String
    public let url: String
    public let tag: String

    public init(type: String = "git", url: String, tag: String) {
        self.type = type
        self.url = url
        self.tag = tag
    }
}

/// An entry in the template registry.
public struct TemplateRegistryEntry: Sendable, Codable, Equatable {
    public let name: String
    public let version: String
    public let description: String
    public let author: String
    public let license: String
    public let platforms: [String]
    public let tags: [String]
    public let source: TemplateSource
    public let manifestSHA256: String

    public init(
        name: String,
        version: String,
        description: String,
        author: String,
        license: String,
        platforms: [String],
        tags: [String] = [],
        source: TemplateSource,
        manifestSHA256: String
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.license = license
        self.platforms = platforms
        self.tags = tags
        self.source = source
        self.manifestSHA256 = manifestSHA256
    }
}

/// The community template registry.
///
/// Parsed from a JSON registry file (e.g., `templates.json` in `swiftanvil-meta`).
public struct TemplateRegistry: Sendable, Codable, Equatable {
    public let registryVersion: Int
    public let lastUpdated: String
    public let templates: [TemplateRegistryEntry]

    public init(
        registryVersion: Int = 1,
        lastUpdated: String,
        templates: [TemplateRegistryEntry]
    ) {
        self.registryVersion = registryVersion
        self.lastUpdated = lastUpdated
        self.templates = templates
    }

    /// Validates the registry structure.
    public func validate() throws {
        guard registryVersion == 1 else {
            throw TemplateRegistryError.invalidRegistryVersion(expected: 1, actual: registryVersion)
        }
        guard !templates.isEmpty else {
            throw TemplateRegistryError.invalidRegistryData("Registry must contain at least one template")
        }
        var seenNames: Set<String> = []
        for template in templates {
            guard !seenNames.contains(template.name) else {
                throw TemplateRegistryError.invalidRegistryData("Duplicate template name: \(template.name)")
            }
            seenNames.insert(template.name)
        }
    }

    /// Finds a template by name.
    public func find(name: String) -> TemplateRegistryEntry? {
        templates.first { $0.name == name }
    }

    /// Returns templates matching the given platform.
    public func templates(for platform: String) -> [TemplateRegistryEntry] {
        templates.filter { $0.platforms.contains(platform) }
    }

    /// Returns templates matching the given tag.
    public func templates(tagged tag: String) -> [TemplateRegistryEntry] {
        templates.filter { $0.tags.contains(tag) }
    }
}

/// Fetches and caches the template registry.
public actor TemplateRegistryFetcher {
    private let registryURL: URL
    private let cacheURL: URL
    private let cacheTTL: TimeInterval
    private let urlSession: URLSession

    /// Creates a fetcher with the given registry URL and cache configuration.
    public init(
        registryURL: URL,
        cacheDirectory: URL? = nil,
        cacheTTL: TimeInterval = 3600,
        urlSession: URLSession = .shared
    ) {
        self.registryURL = registryURL
        cacheURL = cacheDirectory?.appendingPathComponent("registry.json")
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("swiftanvil")
            .appendingPathComponent("registry.json")
        self.cacheTTL = cacheTTL
        self.urlSession = urlSession
    }

    /// Fetches the registry, using cache if valid.
    public func fetch(refresh: Bool = false, offline: Bool = false) async throws -> TemplateRegistry {
        // If offline, only use cache
        if offline {
            return try await loadFromCache()
        }

        // If not refreshing, try cache first
        if !refresh {
            if let cached = try? await loadFromCache(), !isCacheExpired() {
                return cached
            }
        }

        // Fetch from network
        do {
            let (data, _) = try await urlSession.data(from: registryURL)
            let registry = try JSONDecoder().decode(TemplateRegistry.self, from: data)
            try registry.validate()
            try await saveToCache(data)
            return registry
        } catch {
            // Network failed — try stale cache as fallback
            if let cached = try? await loadFromCache() {
                return cached
            }
            throw TemplateRegistryError.networkFailure(error.localizedDescription)
        }
    }

    /// Clears the registry cache.
    public func clearCache() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: cacheURL.path) {
            try fm.removeItem(at: cacheURL)
        }
    }

    // MARK: - Private

    private func loadFromCache() async throws -> TemplateRegistry {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cacheURL.path) else {
            throw TemplateRegistryError.cacheFailure("No cached registry found")
        }
        let data = try Data(contentsOf: cacheURL)
        let registry = try JSONDecoder().decode(TemplateRegistry.self, from: data)
        try registry.validate()
        return registry
    }

    private func saveToCache(_ data: Data) async throws {
        let fm = FileManager.default
        let dir = cacheURL.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
    }

    private func isCacheExpired() -> Bool {
        let fm = FileManager.default
        guard
            fm.fileExists(atPath: cacheURL.path),
            let attrs = try? fm.attributesOfItem(atPath: cacheURL.path),
            let modDate = attrs[.modificationDate] as? Date
        else {
            return true
        }
        return Date().timeIntervalSince(modDate) > cacheTTL
    }
}
