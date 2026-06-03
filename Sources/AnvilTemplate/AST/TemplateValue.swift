import Foundation

/// A value that can be stored in a template context and rendered.
public enum TemplateValue: Sendable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case array([TemplateValue])
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
        } else {
            self = .null
        }
    }
    
    /// Returns the string representation for rendering.
    public var rendered: String {
        switch self {
        case .string(let s): return s
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .array: return ""
        case .null: return ""
        }
    }
    
    /// Returns true if the value is truthy (for #if).
    public var isTruthy: Bool {
        switch self {
        case .bool(let b): return b
        case .string(let s): return !s.isEmpty
        case .int(let i): return i != 0
        case .double(let d): return d != 0
        case .array(let a): return !a.isEmpty
        case .null: return false
        }
    }
    
    /// Returns the array contents if this is an array.
    public var arrayValue: [TemplateValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
}
