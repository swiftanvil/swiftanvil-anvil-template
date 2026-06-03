import Foundation

/// Controls how missing variables are handled during rendering.
public enum RenderMode: Sendable {
    /// Throw `TemplateError.missingVariable` when a variable is not found.
    case strict
    /// Substitute empty string for missing variables.
    case lenient
}
