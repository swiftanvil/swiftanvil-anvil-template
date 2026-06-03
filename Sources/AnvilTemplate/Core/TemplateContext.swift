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
    public func get(_ name: String) -> TemplateValue? {
        storage[name]
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
