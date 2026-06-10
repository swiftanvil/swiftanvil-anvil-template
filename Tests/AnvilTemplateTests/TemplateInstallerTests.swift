import Foundation
#if canImport(CryptoKit)
    import CryptoKit
#endif
import Testing
@testable import AnvilTemplate

@Suite("TemplateInstaller")
struct TemplateInstallerTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Manifest Validation

    @Test("install fails with invalid manifest")
    func invalidManifest() async throws {
        let workDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: workDir) }

        // Create a fake template source with an invalid manifest
        let sourceDir = workDir.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let invalidManifest = """
        {
            "manifestVersion": 99,
            "name": "bad",
            "version": "1.0.0",
            "swiftToolsVersion": "6.0",
            "minimumSwiftanvilVersion": "1.0.0",
            "description": "Bad",
            "author": "swiftanvil",
            "license": "MIT",
            "platforms": ["macOS 15+"],
            "files": [{"source": "a", "destination": "b"}]
        }
        """
        try invalidManifest.write(
            to: sourceDir.appendingPathComponent("anvil-template.yml"),
            atomically: true,
            encoding: .utf8
        )
        try "hello".write(
            to: sourceDir.appendingPathComponent("a"),
            atomically: true,
            encoding: .utf8
        )

        let entry = TemplateRegistryEntry(
            name: "bad",
            version: "1.0.0",
            description: "Bad",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            source: TemplateSource(url: "file://" + sourceDir.path, tag: "1.0.0"),
            manifestSHA256: sha256(Data(invalidManifest.utf8))
        )

        let installer = TemplateInstaller(tempDirectory: workDir)
        let destDir = workDir.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        await #expect(throws: TemplateInstallError.manifestValidationFailed(.invalidManifestVersion(
            expected: 1,
            actual: 99
        ))) {
            _ = try await installer.install(entry: entry, to: destDir)
        }
    }

    @Test("install fails on SHA256 mismatch")
    func sha256Mismatch() async throws {
        let workDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: workDir) }

        let sourceDir = workDir.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let manifest = """
        {
            "manifestVersion": 1,
            "name": "test",
            "version": "1.0.0",
            "swiftToolsVersion": "6.0",
            "minimumSwiftanvilVersion": "1.0.0",
            "description": "Test",
            "author": "swiftanvil",
            "license": "MIT",
            "platforms": ["macOS 15+"],
            "files": [{"source": "a", "destination": "b"}]
        }
        """
        try manifest.write(
            to: sourceDir.appendingPathComponent("anvil-template.yml"),
            atomically: true,
            encoding: .utf8
        )
        try "hello".write(
            to: sourceDir.appendingPathComponent("a"),
            atomically: true,
            encoding: .utf8
        )

        let entry = TemplateRegistryEntry(
            name: "test",
            version: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            source: TemplateSource(url: "file://" + sourceDir.path, tag: "1.0.0"),
            manifestSHA256: "wrongsha256"
        )

        let installer = TemplateInstaller(tempDirectory: workDir)
        let destDir = workDir.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        await #expect(throws: TemplateInstallError.manifestSHA256Mismatch(
            expected: "wrongsha256",
            actual: "8f59364f4dafc6cf95b308c4ffd170e3c4d5c1a94809779258cd941a61d74981"
        )) {
            _ = try await installer.install(entry: entry, to: destDir)
        }
    }

    @Test("install fails when destination exists without force")
    func destinationExistsNoForce() async throws {
        let workDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: workDir) }

        let sourceDir = workDir.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let manifest = """
        {
            "manifestVersion": 1,
            "name": "test",
            "version": "1.0.0",
            "swiftToolsVersion": "6.0",
            "minimumSwiftanvilVersion": "1.0.0",
            "description": "Test",
            "author": "swiftanvil",
            "license": "MIT",
            "platforms": ["macOS 15+"],
            "files": [{"source": "a", "destination": "b"}]
        }
        """
        try manifest.write(
            to: sourceDir.appendingPathComponent("anvil-template.yml"),
            atomically: true,
            encoding: .utf8
        )
        try "hello".write(
            to: sourceDir.appendingPathComponent("a"),
            atomically: true,
            encoding: .utf8
        )

        let entry = TemplateRegistryEntry(
            name: "test",
            version: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            source: TemplateSource(url: "file://" + sourceDir.path, tag: "1.0.0"),
            manifestSHA256: sha256(Data(manifest.utf8))
        )

        let installer = TemplateInstaller(tempDirectory: workDir)
        let destDir = workDir.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        // Pre-create the target directory
        try FileManager.default.createDirectory(
            at: destDir.appendingPathComponent("test", isDirectory: true),
            withIntermediateDirectories: true
        )

        // Path is dynamic — verify the error is thrown by checking type
        let expectedPath = destDir.appendingPathComponent("test").path
        await #expect(throws: TemplateInstallError.destinationExists(expectedPath)) {
            _ = try await installer.install(entry: entry, to: destDir, force: false)
        }
    }

    @Test("install succeeds with force overwrite")
    func forceOverwrite() async throws {
        let workDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: workDir) }

        let sourceDir = workDir.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let manifest = """
        {
            "manifestVersion": 1,
            "name": "test",
            "version": "1.0.0",
            "swiftToolsVersion": "6.0",
            "minimumSwiftanvilVersion": "1.0.0",
            "description": "Test",
            "author": "swiftanvil",
            "license": "MIT",
            "platforms": ["macOS 15+"],
            "files": [{"source": "a", "destination": "b"}]
        }
        """
        try manifest.write(
            to: sourceDir.appendingPathComponent("anvil-template.yml"),
            atomically: true,
            encoding: .utf8
        )
        try "hello".write(
            to: sourceDir.appendingPathComponent("a"),
            atomically: true,
            encoding: .utf8
        )

        let entry = TemplateRegistryEntry(
            name: "test",
            version: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            source: TemplateSource(url: "file://" + sourceDir.path, tag: "1.0.0"),
            manifestSHA256: sha256(Data(manifest.utf8))
        )

        let installer = TemplateInstaller(tempDirectory: workDir)
        let destDir = workDir.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        // Pre-create the target directory
        try FileManager.default.createDirectory(
            at: destDir.appendingPathComponent("test", isDirectory: true),
            withIntermediateDirectories: true
        )

        let result = try await installer.install(entry: entry, to: destDir, force: true)
        #expect(result.lastPathComponent == "test")

        let installedFile = result.appendingPathComponent("b")
        let content = try String(contentsOf: installedFile, encoding: .utf8)
        #expect(content == "hello")
    }

    @Test("install applies variable substitution")
    func variableSubstitution() async throws {
        let workDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: workDir) }

        let sourceDir = workDir.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let manifest = """
        {
            "manifestVersion": 1,
            "name": "test",
            "version": "1.0.0",
            "swiftToolsVersion": "6.0",
            "minimumSwiftanvilVersion": "1.0.0",
            "description": "Test",
            "author": "swiftanvil",
            "license": "MIT",
            "platforms": ["macOS 15+"],
            "files": [{"source": "template.txt", "destination": "output.txt"}],
            "variables": [
                {"name": "projectName", "type": "string", "prompt": "Name", "default": {"type": "string", "value": "DefaultApp"}}
            ]
        }
        """
        try manifest.write(
            to: sourceDir.appendingPathComponent("anvil-template.yml"),
            atomically: true,
            encoding: .utf8
        )
        try "Hello, {{projectName}}!".write(
            to: sourceDir.appendingPathComponent("template.txt"),
            atomically: true,
            encoding: .utf8
        )

        let entry = TemplateRegistryEntry(
            name: "test",
            version: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            source: TemplateSource(url: "file://" + sourceDir.path, tag: "1.0.0"),
            manifestSHA256: sha256(Data(manifest.utf8))
        )

        let installer = TemplateInstaller(tempDirectory: workDir)
        let destDir = workDir.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let result = try await installer.install(
            entry: entry,
            to: destDir,
            variables: ["projectName": .string("MyAwesomeApp")]
        )

        let installedFile = result.appendingPathComponent("output.txt")
        let content = try String(contentsOf: installedFile, encoding: .utf8)
        #expect(content == "Hello, MyAwesomeApp!")
    }

    @Test("install skips platform-filtered files")
    func platformFiltering() async throws {
        let workDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: workDir) }

        let sourceDir = workDir.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let manifest = """
        {
            "manifestVersion": 1,
            "name": "test",
            "version": "1.0.0",
            "swiftToolsVersion": "6.0",
            "minimumSwiftanvilVersion": "1.0.0",
            "description": "Test",
            "author": "swiftanvil",
            "license": "MIT",
            "platforms": ["macOS 15+"],
            "files": [
                {"source": "common.txt", "destination": "common.txt"},
                {"source": "ios.txt", "destination": "ios.txt", "platforms": ["iOS"]}
            ]
        }
        """
        try manifest.write(
            to: sourceDir.appendingPathComponent("anvil-template.yml"),
            atomically: true,
            encoding: .utf8
        )
        try "common".write(
            to: sourceDir.appendingPathComponent("common.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "ios".write(
            to: sourceDir.appendingPathComponent("ios.txt"),
            atomically: true,
            encoding: .utf8
        )

        let entry = TemplateRegistryEntry(
            name: "test",
            version: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            source: TemplateSource(url: "file://" + sourceDir.path, tag: "1.0.0"),
            manifestSHA256: sha256(Data(manifest.utf8))
        )

        let installer = TemplateInstaller(tempDirectory: workDir)
        let destDir = workDir.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let result = try await installer.install(entry: entry, to: destDir)

        let commonFile = result.appendingPathComponent("common.txt")
        let iosFile = result.appendingPathComponent("ios.txt")

        #expect(FileManager.default.fileExists(atPath: commonFile.path))
        #expect(!FileManager.default.fileExists(atPath: iosFile.path))
    }

    @Test("install rolls back on failure")
    func rollbackOnFailure() async throws {
        let workDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: workDir) }

        let sourceDir = workDir.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        // Manifest references a file that doesn't exist — should fail and rollback
        let manifest = """
        {
            "manifestVersion": 1,
            "name": "test",
            "version": "1.0.0",
            "swiftToolsVersion": "6.0",
            "minimumSwiftanvilVersion": "1.0.0",
            "description": "Test",
            "author": "swiftanvil",
            "license": "MIT",
            "platforms": ["macOS 15+"],
            "files": [
                {"source": "exists.txt", "destination": "exists.txt"},
                {"source": "missing.txt", "destination": "missing.txt"}
            ]
        }
        """
        try manifest.write(
            to: sourceDir.appendingPathComponent("anvil-template.yml"),
            atomically: true,
            encoding: .utf8
        )
        try "exists".write(
            to: sourceDir.appendingPathComponent("exists.txt"),
            atomically: true,
            encoding: .utf8
        )

        let entry = TemplateRegistryEntry(
            name: "test",
            version: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            source: TemplateSource(url: "file://" + sourceDir.path, tag: "1.0.0"),
            manifestSHA256: sha256(Data(manifest.utf8))
        )

        let installer = TemplateInstaller(tempDirectory: workDir)
        let destDir = workDir.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let reason = "The file \u{201C}missing.txt\u{201D} couldn\u{2019}t be opened because there is no such file."
        await #expect(throws: TemplateInstallError.fileCopyFailed(source: "", destination: "", reason: reason)) {
            _ = try await installer.install(entry: entry, to: destDir)
        }

        // Verify rollback — target directory should not contain the first file
        let targetDir = destDir.appendingPathComponent("test", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("exists.txt").path))
    }
}

// MARK: - Helpers

private func sha256(_ data: Data) -> String {
    #if canImport(CryptoKit)
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    #else
        return ""
    #endif
}
