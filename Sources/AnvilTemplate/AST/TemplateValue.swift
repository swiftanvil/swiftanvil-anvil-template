import Foundation

/// A value that can be stored in a template context and rendered.
public enum TemplateValue: Sendable, Codable, Equatable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case array([TemplateValue])
    case dictionary([String: TemplateValue])
    case null

    /// Creates a TemplateValue from any supported type.
    public init(_ value: any Sendable) {
        if let string = value as? String {
            self = .string(string)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let int = value as? Int {
            self = .int(int)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let array = value as? [any Sendable] {
            self = .array(array.map { TemplateValue($0) })
        } else if let dictionary = value as? [String: any Sendable] {
            self = .dictionary(dictionary.mapValues { TemplateValue($0) })
        } else {
            self = .null
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "string":
            self = try .string(container.decode(String.self, forKey: .value))
        case "bool":
            self = try .bool(container.decode(Bool.self, forKey: .value))
        case "int":
            self = try .int(container.decode(Int.self, forKey: .value))
        case "double":
            self = try .double(container.decode(Double.self, forKey: .value))
        case "array":
            self = try .array(container.decode([TemplateValue].self, forKey: .value))
        case "dictionary":
            self = try .dictionary(container.decode([String: TemplateValue].self, forKey: .value))
        case "null":
            self = .null
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown TemplateValue type: \(type)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .string(s):
            try container.encode("string", forKey: .type)
            try container.encode(s, forKey: .value)
        case let .bool(b):
            try container.encode("bool", forKey: .type)
            try container.encode(b, forKey: .value)
        case let .int(i):
            try container.encode("int", forKey: .type)
            try container.encode(i, forKey: .value)
        case let .double(d):
            try container.encode("double", forKey: .type)
            try container.encode(d, forKey: .value)
        case let .array(a):
            try container.encode("array", forKey: .type)
            try container.encode(a, forKey: .value)
        case let .dictionary(d):
            try container.encode("dictionary", forKey: .type)
            try container.encode(d, forKey: .value)
        case .null:
            try container.encode("null", forKey: .type)
            try container.encodeNil(forKey: .value)
        }
    }

    /// Returns the string representation for rendering.
    public var rendered: String {
        switch self {
        case let .string(s): s
        case let .bool(b): b ? "true" : "false"
        case let .int(i): String(i)
        case let .double(d): String(d)
        case .array: ""
        case .dictionary: ""
        case .null: ""
        }
    }

    /// Returns true if the value is truthy (for #if).
    public var isTruthy: Bool {
        switch self {
        case let .bool(b): b
        case let .string(s): !s.isEmpty
        case let .int(i): i != 0
        case let .double(d): d != 0
        case let .array(a): !a.isEmpty
        case let .dictionary(d): !d.isEmpty
        case .null: false
        }
    }

    /// Returns the array contents if this is an array.
    public var arrayValue: [TemplateValue]? {
        if case let .array(a) = self { return a }
        return nil
    }

    /// Returns the dictionary contents if this is a dictionary.
    public var dictionaryValue: [String: TemplateValue]? {
        if case let .dictionary(d) = self { return d }
        return nil
    }

    /// Resolves a dot-path such as "user.name" against this value.
    /// If this value is a dictionary, looks up the first path component
    /// and continues recursively. An empty path returns self.
    public func resolve(path: [String]) -> TemplateValue? {
        guard let first = path.first, !first.isEmpty else { return self }
        guard let dict = dictionaryValue else { return nil }
        guard let next = dict[first] else { return nil }
        return next.resolve(path: Array(path.dropFirst()))
    }
}
