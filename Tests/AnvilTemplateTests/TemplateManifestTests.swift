import Foundation
import Testing
@testable import AnvilTemplate

@Suite("TemplateManifest")
struct TemplateManifestTests {
    // MARK: - Valid Manifests

    @Test("validates minimal manifest")
    func minimalManifest() throws {
        let manifest = TemplateManifest(
            name: "test-template",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "A test template",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "Package.swift", destination: "Package.swift")]
        )
        try manifest.validate()
    }

    @Test("validates full manifest")
    func fullManifest() throws {
        let manifest = TemplateManifest(
            name: "swiftui-app",
            version: "1.2.3",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "A SwiftUI app",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["iOS 18+", "macOS 15+", "tvOS 18+", "watchOS 11+", "visionOS 2+"],
            tags: ["ios", "swiftui"],
            files: [
                TemplateFileEntry(source: "Package.swift", destination: "Package.swift"),
                TemplateFileEntry(source: "App.swift", destination: "Sources/App.swift", platforms: ["iOS", "macOS"])
            ],
            exclude: [".git", ".github"],
            variables: [
                TemplateVariable(name: "projectName", type: .string, prompt: "Project name", default: .string("MyApp")),
                TemplateVariable(name: "includeTests", type: .bool, prompt: "Include tests?", default: .bool(true)),
                TemplateVariable(name: "count", type: .int, prompt: "Count", default: .int(5)),
                TemplateVariable(
                    name: "style",
                    type: .choice,
                    prompt: "Style",
                    default: .string("modern"),
                    choices: ["modern", "classic"]
                )
            ]
        )
        try manifest.validate()
    }

    // MARK: - Name Validation

    @Test("rejects empty name")
    func emptyName() {
        let manifest = TemplateManifest(
            name: "",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidField(
            name: "name",
            reason: "Must be 1-50 lowercase alphanumeric or hyphens, not starting/ending with hyphen"
        )) {
            try manifest.validate()
        }
    }

    @Test("rejects name starting with hyphen")
    func nameStartsWithHyphen() {
        let manifest = TemplateManifest(
            name: "-bad",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidField(
            name: "name",
            reason: "Must be 1-50 lowercase alphanumeric or hyphens, not starting/ending with hyphen"
        )) {
            try manifest.validate()
        }
    }

    @Test("rejects name with uppercase")
    func nameUppercase() {
        let manifest = TemplateManifest(
            name: "BadName",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidField(
            name: "name",
            reason: "Must be 1-50 lowercase alphanumeric or hyphens, not starting/ending with hyphen"
        )) {
            try manifest.validate()
        }
    }

    @Test("rejects name over 50 chars")
    func nameTooLong() {
        let manifest = TemplateManifest(
            name: String(repeating: "a", count: 51),
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidField(
            name: "name",
            reason: "Must be 1-50 lowercase alphanumeric or hyphens, not starting/ending with hyphen"
        )) {
            try manifest.validate()
        }
    }

    // MARK: - Version Validation

    @Test("rejects invalid semver")
    func invalidSemVer() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidSemVer("1.0")) {
            try manifest.validate()
        }
    }

    @Test("rejects invalid swift tools version")
    func invalidSwiftToolsVersion() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0.1.2",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidSwiftToolsVersion("6.0.1.2")) {
            try manifest.validate()
        }
    }

    // MARK: - Platform Validation

    @Test("rejects invalid platform")
    func invalidPlatform() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["Windows 11"],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidPlatform("Windows 11")) {
            try manifest.validate()
        }
    }

    @Test("rejects empty platforms")
    func emptyPlatforms() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: [],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.missingField("platforms")) {
            try manifest.validate()
        }
    }

    // MARK: - Path Traversal Protection

    @Test("rejects destination with parent traversal")
    func destinationTraversal() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "../../etc/passwd")]
        )
        #expect(throws: TemplateManifestError.pathTraversalDetected("../../etc/passwd")) {
            try manifest.validate()
        }
    }

    @Test("rejects absolute destination")
    func absoluteDestination() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "/etc/passwd")]
        )
        #expect(throws: TemplateManifestError.pathTraversalDetected("/etc/passwd")) {
            try manifest.validate()
        }
    }

    @Test("rejects source with parent traversal")
    func sourceTraversal() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "../secret", destination: "b")]
        )
        #expect(throws: TemplateManifestError.pathTraversalDetected("../secret")) {
            try manifest.validate()
        }
    }

    // MARK: - Variable Validation

    @Test("rejects invalid variable name")
    func invalidVariableName() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")],
            variables: [
                TemplateVariable(name: "123bad", type: .string, prompt: "Bad")
            ]
        )
        #expect(throws: TemplateManifestError.invalidVariableName("123bad")) {
            try manifest.validate()
        }
    }

    @Test("rejects choice without choices")
    func choiceWithoutChoices() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")],
            variables: [
                TemplateVariable(name: "style", type: .choice, prompt: "Style")
            ]
        )
        #expect(throws: TemplateManifestError.invalidField(
            name: "variables.style.choices",
            reason: "Choice variables must have non-empty choices array"
        )) {
            try manifest.validate()
        }
    }

    // MARK: - Default Values

    @Test("returns default variable values")
    func defaultValues() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")],
            variables: [
                TemplateVariable(name: "name", type: .string, prompt: "Name", default: .string("MyApp")),
                TemplateVariable(name: "count", type: .int, prompt: "Count", default: .int(42)),
                TemplateVariable(name: "enabled", type: .bool, prompt: "Enabled", default: .bool(true)),
                TemplateVariable(
                    name: "style",
                    type: .choice,
                    prompt: "Style",
                    default: .string("modern"),
                    choices: ["modern", "classic"]
                )
            ]
        )
        let defaults = manifest.defaultVariableValues()
        #expect(defaults["name"] == .string("MyApp"))
        #expect(defaults["count"] == .int(42))
        #expect(defaults["enabled"] == .bool(true))
        #expect(defaults["style"] == .string("modern"))
    }

    @Test("provides fallback defaults when not specified")
    func fallbackDefaults() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")],
            variables: [
                TemplateVariable(name: "name", type: .string, prompt: "Name"),
                TemplateVariable(name: "count", type: .int, prompt: "Count"),
                TemplateVariable(name: "enabled", type: .bool, prompt: "Enabled"),
                TemplateVariable(name: "style", type: .choice, prompt: "Style", choices: ["modern", "classic"])
            ]
        )
        let defaults = manifest.defaultVariableValues()
        #expect(defaults["name"] == .string(""))
        #expect(defaults["count"] == .int(0))
        #expect(defaults["enabled"] == .bool(false))
        #expect(defaults["style"] == .string("modern"))
    }

    // MARK: - Edge Cases

    @Test("rejects empty files list")
    func emptyFiles() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: []
        )
        #expect(throws: TemplateManifestError.missingField("files")) {
            try manifest.validate()
        }
    }

    @Test("rejects description over 200 chars")
    func descriptionTooLong() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: String(repeating: "a", count: 201),
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidField(name: "description", reason: "Max 200 characters")) {
            try manifest.validate()
        }
    }

    @Test("rejects too many tags")
    func tooManyTags() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            tags: (1 ... 11).map { "tag\($0)" },
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidField(name: "tags", reason: "Max 10 tags")) {
            try manifest.validate()
        }
    }

    @Test("rejects tag over 20 chars")
    func tagTooLong() {
        let manifest = TemplateManifest(
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            tags: [String(repeating: "a", count: 21)],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidField(name: "tags", reason: "Each tag max 20 characters")) {
            try manifest.validate()
        }
    }

    @Test("rejects invalid manifest version")
    func invalidManifestVersion() {
        let manifest = TemplateManifest(
            manifestVersion: 2,
            name: "test",
            version: "1.0.0",
            swiftToolsVersion: "6.0",
            minimumSwiftanvilVersion: "1.0.0",
            description: "Test",
            author: "swiftanvil",
            license: "MIT",
            platforms: ["macOS 15+"],
            files: [TemplateFileEntry(source: "a", destination: "b")]
        )
        #expect(throws: TemplateManifestError.invalidManifestVersion(expected: 1, actual: 2)) {
            try manifest.validate()
        }
    }
}
