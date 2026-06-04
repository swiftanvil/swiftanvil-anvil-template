import Foundation

/// Stores variable values for template rendering.
public struct TemplateContext: Sendable {
    private var storage: [String: TemplateValue]
    
    /// Creates a context from a dictionary.
    public init(_ values: [String: any Sendable] = [:]) {
        self.storage = values.mapValues { TemplateValue($0) }
    }
    
    /// Creates a context from TemplateValues directly.
    public init(values: [String: TemplateValue] = [:]) {
        self.storage = values
    }
    
    /// Retrieves a value by name.
    /// Supports dot-paths such as "user.name" for dictionary traversal.
    /// Also supports ".field" to look up "field" on the current loop item
    /// stored under the special "." key.
    public func get(_ name: String) -> TemplateValue? {
        let components = name.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard let first = components.first else { return nil }
        // Dot-path starting with "." (e.g. ".name") — resolve against the
        // loop item stored under the special "." key.
        if first.isEmpty, components.count > 1 {
            guard let loopItem = storage["."] else { return nil }
            return loopItem.resolve(path: Array(components.dropFirst()))
        }
        guard let root = storage[first] else { return nil }
        if components.count == 1 { return root }
        return root.resolve(path: Array(components.dropFirst()))
    }
    
    /// Sets a value.
    public mutating func set(_ name: String, value: any Sendable) {
        storage[name] = TemplateValue(value)
    }
    
    /// Sets a TemplateValue directly.
    public mutating func set(_ name: String, value: TemplateValue) {
        storage[name] = value
    }
}
