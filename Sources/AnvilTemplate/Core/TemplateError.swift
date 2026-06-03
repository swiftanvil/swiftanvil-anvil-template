import Foundation

/// Errors that can occur during template parsing or rendering.
public enum TemplateError: Error, Sendable, Equatable {
    case parseError(message: String, position: Int)
    case missingVariable(String)
    case typeMismatch(variable: String, expected: String, actual: String)
}
