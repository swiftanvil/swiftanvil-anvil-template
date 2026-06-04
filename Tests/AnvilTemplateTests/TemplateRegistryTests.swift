import Foundation
import Testing
@testable import AnvilTemplate

@Suite("TemplateRegistry")
struct TemplateRegistryTests {

    // MARK: - Validation

    @Test("validates minimal registry")
    func minimalRegistry() throws {
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: [
                TemplateRegistryEntry(
                    name: "swiftui-app",
                    version: "1.0.0",
                    description: "A SwiftUI app",
                    author: "swiftanvil",
                    license: "MIT",
                    platforms: ["iOS 18+", "macOS 15+"],
                    source: TemplateSource(url: "https://github.com/swiftanvil/swiftanvil-template-swiftui", tag: "1.0.0"),
                    manifestSHA256: "abc123"
                )
            ]
        )
        try registry.validate()
    }

    @Test("rejects empty registry")
    func emptyRegistry() {
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: []
        )
        #expect(throws: TemplateRegistryError.invalidRegistryData("Registry must contain at least one template")) {
            try registry.validate()
        }
    }

    @Test("rejects invalid registry version")
    func invalidRegistryVersion() {
        let registry = TemplateRegistry(
            registryVersion: 2,
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: [
                TemplateRegistryEntry(
                    name: "swiftui-app",
                    version: "1.0.0",
                    description: "A SwiftUI app",
                    author: "swiftanvil",
                    license: "MIT",
                    platforms: ["iOS 18+"],
                    source: TemplateSource(url: "https://github.com/swiftanvil/swiftanvil-template-swiftui", tag: "1.0.0"),
                    manifestSHA256: "abc123"
                )
            ]
        )
        #expect(throws: TemplateRegistryError.invalidRegistryVersion(expected: 1, actual: 2)) {
            try registry.validate()
        }
    }

    @Test("rejects duplicate template names")
    func duplicateNames() {
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: [
                TemplateRegistryEntry(
                    name: "swiftui-app",
                    version: "1.0.0",
                    description: "A",
                    author: "swiftanvil",
                    license: "MIT",
                    platforms: ["iOS 18+"],
                    source: TemplateSource(url: "https://github.com/swiftanvil/a", tag: "1.0.0"),
                    manifestSHA256: "abc"
                ),
                TemplateRegistryEntry(
                    name: "swiftui-app",
                    version: "2.0.0",
                    description: "B",
                    author: "swiftanvil",
                    license: "MIT",
                    platforms: ["iOS 18+"],
                    source: TemplateSource(url: "https://github.com/swiftanvil/b", tag: "2.0.0"),
                    manifestSHA256: "def"
                )
            ]
        )
        #expect(throws: TemplateRegistryError.invalidRegistryData("Duplicate template name: swiftui-app")) {
            try registry.validate()
        }
    }

    // MARK: - Queries

    @Test("finds template by name")
    func findByName() {
        let entry = TemplateRegistryEntry(
            name: "cli-tool",
            version: "1.0.0",
            description: "A CLI tool",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            source: TemplateSource(url: "https://github.com/swiftanvil/cli", tag: "1.0.0"),
            manifestSHA256: "abc123"
        )
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: [entry]
        )
        let found = registry.find(name: "cli-tool")
        #expect(found == entry)
        #expect(registry.find(name: "missing") == nil)
    }

    @Test("filters by platform")
    func filterByPlatform() {
        let ios = TemplateRegistryEntry(
            name: "ios-app",
            version: "1.0.0",
            description: "iOS app",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["iOS 18+"],
            source: TemplateSource(url: "https://github.com/swiftanvil/ios", tag: "1.0.0"),
            manifestSHA256: "abc"
        )
        let macos = TemplateRegistryEntry(
            name: "macos-app",
            version: "1.0.0",
            description: "macOS app",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            source: TemplateSource(url: "https://github.com/swiftanvil/macos", tag: "1.0.0"),
            manifestSHA256: "def"
        )
        let multi = TemplateRegistryEntry(
            name: "multi-app",
            version: "1.0.0",
            description: "Multiplatform app",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["iOS 18+", "macOS 15+"],
            source: TemplateSource(url: "https://github.com/swiftanvil/multi", tag: "1.0.0"),
            manifestSHA256: "ghi"
        )
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: [ios, macos, multi]
        )
        #expect(registry.templates(for: "iOS 18+").count == 2)
        #expect(registry.templates(for: "macOS 15+").count == 2)
        #expect(registry.templates(for: "tvOS 18+").isEmpty)
    }

    @Test("filters by tag")
    func filterByTag() {
        let app = TemplateRegistryEntry(
            name: "app",
            version: "1.0.0",
            description: "An app",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["iOS 18+"],
            tags: ["swiftui", "ios"],
            source: TemplateSource(url: "https://github.com/swiftanvil/app", tag: "1.0.0"),
            manifestSHA256: "abc"
        )
        let lib = TemplateRegistryEntry(
            name: "lib",
            version: "1.0.0",
            description: "A library",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            tags: ["library"],
            source: TemplateSource(url: "https://github.com/swiftanvil/lib", tag: "1.0.0"),
            manifestSHA256: "def"
        )
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: [app, lib]
        )
        #expect(registry.templates(tagged: "swiftui").count == 1)
        #expect(registry.templates(tagged: "ios").count == 1)
        #expect(registry.templates(tagged: "library").count == 1)
        #expect(registry.templates(tagged: "missing").isEmpty)
    }

    // MARK: - Codable

    @Test("round-trips through JSON")
    func jsonRoundTrip() throws {
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: [
                TemplateRegistryEntry(
                    name: "test",
                    version: "1.0.0",
                    description: "Test",
                    author: "swiftanvil",
                    license: "MIT",
                    platforms: ["macOS 15+"],
                    tags: ["test"],
                    source: TemplateSource(url: "https://example.com/test", tag: "1.0.0"),
                    manifestSHA256: "deadbeef"
                )
            ]
        )
        let data = try JSONEncoder().encode(registry)
        let decoded = try JSONDecoder().decode(TemplateRegistry.self, from: data)
        #expect(decoded == registry)
    }
}

@Suite("TemplateRegistryFetcher")
struct TemplateRegistryFetcherTests {

    @Test("fetches from cache when valid")
    func cacheHit() async throws {
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: [
                TemplateRegistryEntry(
                    name: "cached",
                    version: "1.0.0",
                    description: "Cached",
                    author: "swiftanvil",
                    license: "MIT",
                    platforms: ["macOS 15+"],
                    source: TemplateSource(url: "https://example.com/cached", tag: "1.0.0"),
                    manifestSHA256: "abc"
                )
            ]
        )

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fetcher = TemplateRegistryFetcher(
            registryURL: URL(string: "https://example.com/registry.json")!,
            cacheDirectory: tempDir,
            cacheTTL: 3600
        )

        // Prime cache
        let data = try JSONEncoder().encode(registry)
        let cacheFile = tempDir.appendingPathComponent("registry.json")
        try data.write(to: cacheFile)

        let result = try await fetcher.fetch(refresh: false, offline: false)
        #expect(result == registry)
    }

    @Test("offline mode uses cache")
    func offlineMode() async throws {
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: [
                TemplateRegistryEntry(
                    name: "offline",
                    version: "1.0.0",
                    description: "Offline",
                    author: "swiftanvil",
                    license: "MIT",
                    platforms: ["macOS 15+"],
                    source: TemplateSource(url: "https://example.com/offline", tag: "1.0.0"),
                    manifestSHA256: "abc"
                )
            ]
        )

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fetcher = TemplateRegistryFetcher(
            registryURL: URL(string: "https://example.com/registry.json")!,
            cacheDirectory: tempDir,
            cacheTTL: 3600
        )

        // Prime cache
        let data = try JSONEncoder().encode(registry)
        let cacheFile = tempDir.appendingPathComponent("registry.json")
        try data.write(to: cacheFile)

        let result = try await fetcher.fetch(refresh: false, offline: true)
        #expect(result == registry)
    }

    @Test("throws when offline and no cache")
    func offlineNoCache() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fetcher = TemplateRegistryFetcher(
            registryURL: URL(string: "https://example.com/registry.json")!,
            cacheDirectory: tempDir,
            cacheTTL: 3600
        )

        await #expect(throws: TemplateRegistryError.cacheFailure("No cached registry found")) {
            _ = try await fetcher.fetch(refresh: false, offline: true)
        }
    }

    @Test("clears cache")
    func clearCache() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fetcher = TemplateRegistryFetcher(
            registryURL: URL(string: "https://example.com/registry.json")!,
            cacheDirectory: tempDir,
            cacheTTL: 3600
        )

        // Prime cache
        let registry = TemplateRegistry(
            lastUpdated: "2026-06-04T12:00:00Z",
            templates: []
        )
        let data = try JSONEncoder().encode(registry)
        let cacheFile = tempDir.appendingPathComponent("registry.json")
        try data.write(to: cacheFile)

        try await fetcher.clearCache()
        #expect(!FileManager.default.fileExists(atPath: cacheFile.path))
    }
}
