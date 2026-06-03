import Foundation

/// A node in the template AST.
public enum TemplateNode: Sendable {
    /// Plain text.
    case text(String)
    /// Variable substitution: {{name}}
    case variable(String)
    /// Conditional block: {{#if condition}}...{{/if}}
    case conditional(variable: String, body: [TemplateNode])
    /// Loop block: {{#each items}}...{{/each}}
    case loop(variable: String, body: [TemplateNode])
    /// Comment: {{! comment }}
    case comment(String)
}
