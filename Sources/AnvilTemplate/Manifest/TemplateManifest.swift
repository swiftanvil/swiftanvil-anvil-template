import Foundation

/// Errors that can occur during template manifest parsing or validation.
public enum TemplateManifestError: Error, Sendable, Equatable {
    case invalidManifestVersion(expected: Int, actual: Int)
    case missingField(String)
    case invalidField(name: String, reason: String)
    case invalidSemVer(String)
    case invalidSwiftToolsVersion(String)
    case invalidPlatform(String)
    case invalidVariableType(String)
    case invalidVariableName(String)
    case pathTraversalDetected(String)
    case invalidFileEntry(reason: String)
}

/// A template variable definition.
public struct TemplateVariable: Sendable, Codable, Equatable {
    public let name: String
    public let type: VariableType
    public let prompt: String
    public let `default`: TemplateValue?
    public let choices: [String]?

    public enum VariableType: String, Sendable, Codable, Equatable {
        case string
        case int
        case bool
        case choice
    }

    public init(
        name: String,
        type: VariableType,
        prompt: String,
        default: TemplateValue? = nil,
        choices: [String]? = nil
    ) {
        self.name = name
        self.type = type
        self.prompt = prompt
        self.default = `default`
        self.choices = choices
    }
}

/// A file entry in a template manifest.
public struct TemplateFileEntry: Sendable, Codable, Equatable {
    public let source: String
    public let destination: String
    public let platforms: [String]?

    public init(source: String, destination: String, platforms: [String]? = nil) {
        self.source = source
        self.destination = destination
        self.platforms = platforms
    }
}

/// A community template manifest (v1 schema).
///
/// Parsed from `anvil-template.yml` in a template repository.
public struct TemplateManifest: Sendable, Codable, Equatable {
    public let manifestVersion: Int
    public let name: String
    public let version: String
    public let swiftToolsVersion: String
    public let minimumSwiftanvilVersion: String
    public let description: String
    public let author: String
    public let license: String
    public let platforms: [String]
    public let tags: [String]?
    public let files: [TemplateFileEntry]
    public let exclude: [String]?
    public let variables: [TemplateVariable]?

    public init(
        manifestVersion: Int = 1,
        name: String,
        version: String,
        swiftToolsVersion: String,
        minimumSwiftanvilVersion: String,
        description: String,
        author: String,
        license: String,
        platforms: [String],
        tags: [String]? = nil,
        files: [TemplateFileEntry],
        exclude: [String]? = nil,
        variables: [TemplateVariable]? = nil
    ) {
        self.manifestVersion = manifestVersion
        self.name = name
        self.version = version
        self.swiftToolsVersion = swiftToolsVersion
        self.minimumSwiftanvilVersion = minimumSwiftanvilVersion
        self.description = description
        self.author = author
        self.license = license
        self.platforms = platforms
        self.tags = tags
        self.files = files
        self.exclude = exclude
        self.variables = variables
    }

    /// Validates the manifest against the v1 schema rules.
    public func validate() throws {
        guard manifestVersion == 1 else {
            throw TemplateManifestError.invalidManifestVersion(expected: 1, actual: manifestVersion)
        }

        // Name: lowercase alphanumeric + hyphens, max 50
        guard
            name.count <= 50,
            name.allSatisfy({ $0.isLowercase || $0.isNumber || $0 == "-" }),
            !name.isEmpty,
            name.first != "-",
            name.last != "-"
        else {
            throw TemplateManifestError.invalidField(
                name: "name",
                reason: "Must be 1-50 lowercase alphanumeric or hyphens, not starting/ending with hyphen"
            )
        }

        // SemVer validation
        guard isValidSemVer(version) else {
            throw TemplateManifestError.invalidSemVer(version)
        }
        guard isValidSemVer(minimumSwiftanvilVersion) else {
            throw TemplateManifestError.invalidSemVer(minimumSwiftanvilVersion)
        }

        // Swift tools version
        guard isValidSwiftToolsVersion(swiftToolsVersion) else {
            throw TemplateManifestError.invalidSwiftToolsVersion(swiftToolsVersion)
        }

        // Description max 200
        guard description.count <= 200 else {
            throw TemplateManifestError.invalidField(name: "description", reason: "Max 200 characters")
        }

        // Author max 100
        guard author.count <= 100 else {
            throw TemplateManifestError.invalidField(name: "author", reason: "Max 100 characters")
        }

        // Platforms
        let validPlatforms = [
            "iOS 18+", "macOS 15+", "tvOS 18+", "watchOS 11+", "visionOS 2+"
        ]
        guard !platforms.isEmpty else {
            throw TemplateManifestError.missingField("platforms")
        }
        for platform in platforms {
            guard validPlatforms.contains(platform) else {
                throw TemplateManifestError.invalidPlatform(platform)
            }
        }

        // Tags
        let tagsArray = tags ?? []
        guard tagsArray.count <= 10 else {
            throw TemplateManifestError.invalidField(name: "tags", reason: "Max 10 tags")
        }
        for tag in tagsArray {
            guard tag.count <= 20 else {
                throw TemplateManifestError.invalidField(name: "tags", reason: "Each tag max 20 characters")
            }
        }

        // Files: at least one
        guard !files.isEmpty else {
            throw TemplateManifestError.missingField("files")
        }

        for file in files {
            // Path traversal protection
            guard !file.destination.contains("..") else {
                throw TemplateManifestError.pathTraversalDetected(file.destination)
            }
            guard !file.destination.hasPrefix("/") else {
                throw TemplateManifestError.pathTraversalDetected(file.destination)
            }
            guard !file.source.contains("..") else {
                throw TemplateManifestError.pathTraversalDetected(file.source)
            }
        }

        // Variables
        let variablesArray = variables ?? []
        for variable in variablesArray {
            guard isValidSwiftIdentifier(variable.name) else {
                throw TemplateManifestError.invalidVariableName(variable.name)
            }
            switch variable.type {
            case .choice:
                guard let choices = variable.choices, !choices.isEmpty else {
                    throw TemplateManifestError.invalidField(
                        name: "variables.\(variable.name).choices",
                        reason: "Choice variables must have non-empty choices array"
                    )
                }
            default:
                break
            }
        }
    }

    /// Returns the default values for all variables as a dictionary.
    public func defaultVariableValues() -> [String: TemplateValue] {
        var result: [String: TemplateValue] = [:]
        let variablesArray = variables ?? []
        for variable in variablesArray {
            if let defaultValue = variable.default {
                result[variable.name] = defaultValue
            } else {
                // Provide sensible defaults
                switch variable.type {
                case .string: result[variable.name] = .string("")
                case .int: result[variable.name] = .int(0)
                case .bool: result[variable.name] = .bool(false)
                case .choice:
                    if let firstChoice = variable.choices?.first {
                        result[variable.name] = .string(firstChoice)
                    } else {
                        result[variable.name] = .string("")
                    }
                }
            }
        }
        return result
    }
}

// MARK: - Validation Helpers

private func isValidSemVer(_ version: String) -> Bool {
    let parts = version.split(separator: ".")
    guard parts.count == 3 else { return false }
    for part in parts {
        guard let _ = Int(part) else { return false }
    }
    return true
}

private func isValidSwiftToolsVersion(_ version: String) -> Bool {
    let parts = version.split(separator: ".")
    guard parts.count >= 1, parts.count <= 2 else { return false }
    for part in parts {
        guard let _ = Int(part) else { return false }
    }
    return true
}

private func isValidSwiftIdentifier(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }
    let first = name.first!
    guard first.isLetter || first == "_" else { return false }
    for char in name.dropFirst() {
        guard char.isLetter || char.isNumber || char == "_" else { return false }
    }
    return true
}
