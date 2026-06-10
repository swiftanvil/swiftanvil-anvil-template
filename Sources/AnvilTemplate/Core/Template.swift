import Foundation

/// A parsed template that can be rendered with a context.
public struct Template: Sendable {
    private let nodes: [TemplateNode]
    private let renderer = TemplateRenderer()

    /// Parses a template from a string.
    public init(_ source: String) throws {
        nodes = try TemplateParser().parse(source)
    }

    /// Loads and parses a template from a file URL.
    public init(contentsOf url: URL) throws {
        let source = try String(contentsOf: url, encoding: .utf8)
        nodes = try TemplateParser().parse(source)
    }

    /// Renders the template with the given context.
    public func render(context: TemplateContext, mode: RenderMode = .lenient) throws -> String {
        try renderer.render(nodes: nodes, context: context, mode: mode)
    }
}

// Convenience: dictionary literal → TemplateContext
public extension Template {
    func render(context: [String: any Sendable], mode: RenderMode = .lenient) throws -> String {
        try render(context: TemplateContext(context), mode: mode)
    }
}
