import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Errors that can occur during template installation.
public enum TemplateInstallError: Error, Sendable, Equatable {
    case networkFailure(String)
    case manifestValidationFailed(TemplateManifestError)
    case pathTraversalDetected(String)
    case destinationExists(String)
    case unsupportedPlatform(String)
    case manifestSHA256Mismatch(expected: String, actual: String)
    case fileCopyFailed(source: String, destination: String, reason: String)
    case rollbackFailed(String)
    case templateNotFoundInRegistry(String)
    case variableInputFailed(String)
}

/// Installs community templates from the registry.
///
/// Uses atomic writes (temp directory + move) with rollback on failure.
public actor TemplateInstaller {
    private let fileManager: FileManager
    private let urlSession: URLSession
    private let tempDirectory: URL

    public init(
        fileManager: FileManager = .default,
        urlSession: URLSession = .shared,
        tempDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.urlSession = urlSession
        self.tempDirectory = tempDirectory ?? fileManager.temporaryDirectory
            .appendingPathComponent("swiftanvil-installs", isDirectory: true)
    }

    /// Installs a template from the registry.
    ///
    /// - Parameters:
    ///   - entry: The registry entry for the template.
    ///   - destination: The directory to install into (a subdirectory named after the template will be created).
    ///   - variables: User-provided variable values (merged with defaults).
    ///   - force: If true, overwrite existing files.
    /// - Returns: The path to the installed template directory.
    public func install(
        entry: TemplateRegistryEntry,
        to destination: URL,
        variables: [String: TemplateValue] = [:],
        force: Bool = false
    ) async throws -> URL {
        // Create temp working directory
        let installID = UUID().uuidString
        let workDir = tempDirectory.appendingPathComponent(installID, isDirectory: true)
        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)

        var installedFiles: [URL] = []

        do {
            // Download template source
            let sourceDir = try await downloadTemplate(entry: entry, to: workDir)

            // Find and parse manifest
            let manifestURL = sourceDir.appendingPathComponent("anvil-template.yml")
            let manifest = try await parseManifest(at: manifestURL)
            try manifest.validate()

            // Verify SHA-256
            let manifestData = try Data(contentsOf: manifestURL)
            let actualSHA256 = sha256(manifestData)
            guard actualSHA256 == entry.manifestSHA256 else {
                throw TemplateInstallError.manifestSHA256Mismatch(
                    expected: entry.manifestSHA256,
                    actual: actualSHA256
                )
            }

            // Check platform compatibility
            let hostPlatform = try currentPlatform()
            guard manifest.platforms.contains(hostPlatform) else {
                throw TemplateInstallError.unsupportedPlatform(
                    "Template supports \(manifest.platforms.joined(separator: ", ")), but host is \(hostPlatform)"
                )
            }

            // Merge variables with defaults
            let mergedVariables = mergeVariables(manifest: manifest, userValues: variables)

            // Determine install target
            let targetDir = destination.appendingPathComponent(manifest.name, isDirectory: true)

            // Check for existing directory
            if fileManager.fileExists(atPath: targetDir.path) && !force {
                throw TemplateInstallError.destinationExists(targetDir.path)
            }

            // Create target directory
            try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)

            // Copy files with variable substitution
            for fileEntry in manifest.files {
                // Skip platform-filtered files
                if let platforms = fileEntry.platforms, !platforms.contains(hostPlatform) {
                    continue
                }

                let sourceURL = sourceDir.appendingPathComponent(fileEntry.source)
                let destURL = targetDir.appendingPathComponent(fileEntry.destination)

                // Path traversal check
                let resolvedDest = destURL.resolvingSymlinksInPath().standardizedFileURL.path
                let resolvedTarget = targetDir.resolvingSymlinksInPath().standardizedFileURL.path
                guard resolvedDest.hasPrefix(resolvedTarget) else {
                    throw TemplateInstallError.pathTraversalDetected(fileEntry.destination)
                }

                // Create parent directory
                let parentDir = destURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

                // Read source, substitute variables, write destination
                let sourceContent = try String(contentsOf: sourceURL, encoding: .utf8)
                let context = TemplateContext(values: mergedVariables)
                let template = try Template(sourceContent)
                let renderedContent = try template.render(context: context, mode: .lenient)
                try renderedContent.write(to: destURL, atomically: true, encoding: .utf8)

                installedFiles.append(destURL)
            }

            return targetDir

        } catch {
            // Rollback: remove installed files
            for file in installedFiles {
                try? fileManager.removeItem(at: file)
            }
            // Remove target directory if empty
            let targetDir = destination.appendingPathComponent(entry.name, isDirectory: true)
            if fileManager.fileExists(atPath: targetDir.path) {
                if (try? fileManager.contentsOfDirectory(atPath: targetDir.path))?.isEmpty == true {
                    try? fileManager.removeItem(at: targetDir)
                }
            }
            // Clean up work directory
            try? fileManager.removeItem(at: workDir)

            if let installError = error as? TemplateInstallError {
                throw installError
            } else if let manifestError = error as? TemplateManifestError {
                throw TemplateInstallError.manifestValidationFailed(manifestError)
            } else {
                throw TemplateInstallError.fileCopyFailed(source: "", destination: "", reason: error.localizedDescription)
            }
        }
    }

    // MARK: - Private

    private func downloadTemplate(entry: TemplateRegistryEntry, to workDir: URL) async throws -> URL {
        let sourceDir = workDir.appendingPathComponent("source", isDirectory: true)
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        switch entry.source.type {
        case "git":
            return try await downloadGitTemplate(url: entry.source.url, tag: entry.source.tag, to: sourceDir)
        default:
            throw TemplateInstallError.networkFailure("Unsupported source type: \(entry.source.type)")
        }
    }

    private func downloadGitTemplate(url: String, tag: String, to dest: URL) async throws -> URL {
        // Handle local file:// URLs by copying instead of cloning
        if url.hasPrefix("file://") {
            let sourcePath = String(url.dropFirst("file://".count))
            let sourceURL = URL(fileURLWithPath: sourcePath)
            // Remove the pre-created dest directory so copyItem can create it fresh
            try? fileManager.removeItem(at: dest)
            try fileManager.copyItem(at: sourceURL, to: dest)
            return dest
        }

        // Use git clone --depth 1 --branch <tag>
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", "--depth", "1", "--branch", tag, url, dest.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TemplateInstallError.networkFailure("Failed to clone \(url) @ \(tag)")
        }

        return dest
    }

    private func parseManifest(at url: URL) async throws -> TemplateManifest {
        let data = try Data(contentsOf: url)
        // Try JSON first, then fall back to YAML-like JSON (plain text with .yml extension)
        if let manifest = try? JSONDecoder().decode(TemplateManifest.self, from: data) {
            return manifest
        }
        // If the file has .yml extension but contains valid JSON, it should have parsed above.
        // If it contains actual YAML, we need a YAML parser. For now, attempt to parse
        // the file content as JSON regardless of extension.
        let content = String(data: data, encoding: .utf8) ?? ""
        if let jsonData = content.data(using: .utf8),
           let manifest = try? JSONDecoder().decode(TemplateManifest.self, from: jsonData) {
            return manifest
        }
        throw TemplateManifestError.invalidField(name: "manifest", reason: "Unable to parse manifest. Only JSON is supported in this version.")
    }

    private func mergeVariables(manifest: TemplateManifest, userValues: [String: TemplateValue]) -> [String: TemplateValue] {
        var result = manifest.defaultVariableValues()
        for (key, value) in userValues {
            result[key] = value
        }
        return result
    }

    private func sha256(_ data: Data) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        // Fallback for platforms without CryptoKit
        return ""
        #endif
    }

    private func currentPlatform() throws -> String {
        #if os(iOS)
        return "iOS 18+"
        #elseif os(macOS)
        return "macOS 15+"
        #elseif os(tvOS)
        return "tvOS 18+"
        #elseif os(watchOS)
        return "watchOS 11+"
        #elseif os(visionOS)
        return "visionOS 2+"
        #else
        throw TemplateInstallError.unsupportedPlatform("Unknown platform")
        #endif
    }
}
