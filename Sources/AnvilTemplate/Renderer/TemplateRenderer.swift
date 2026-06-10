import Foundation

/// Renders a template AST into a string using a context.
public struct TemplateRenderer: Sendable {
    public init() { }

    /// Renders an array of AST nodes.
    public func render(nodes: [TemplateNode], context: TemplateContext, mode: RenderMode) throws -> String {
        var output = ""
        for node in nodes {
            output += try render(node: node, context: context, mode: mode)
        }
        return output
    }

    private func render(node: TemplateNode, context: TemplateContext, mode: RenderMode) throws -> String {
        switch node {
        case let .text(text):
            return text

        case let .variable(name):
            if let value = context.get(name) {
                return value.rendered
            }
            switch mode {
            case .strict:
                throw TemplateError.missingVariable(name)
            case .lenient:
                return ""
            }

        case let .conditional(variable, body):
            guard let value = context.get(variable) else {
                switch mode {
                case .strict:
                    throw TemplateError.missingVariable(variable)
                case .lenient:
                    return ""
                }
            }
            if value.isTruthy {
                return try render(nodes: body, context: context, mode: mode)
            }
            return ""

        case let .loop(variable, body):
            guard let value = context.get(variable) else {
                switch mode {
                case .strict:
                    throw TemplateError.missingVariable(variable)
                case .lenient:
                    return ""
                }
            }
            guard let items = value.arrayValue else {
                throw TemplateError.typeMismatch(
                    variable: variable,
                    expected: "Array",
                    actual: String(describing: type(of: value))
                )
            }
            var output = ""
            for item in items {
                var loopContext = context
                loopContext.set(".", value: item)
                output += try render(nodes: body, context: loopContext, mode: mode)
            }
            return output

        case .comment:
            return ""
        }
    }
}
