import Foundation

/// Parses template strings into an AST.
public struct TemplateParser: Sendable {
    public init() { }

    /// Parses a template string into an array of AST nodes.
    public func parse(_ source: String) throws -> [TemplateNode] {
        var nodes: [TemplateNode] = []
        var position = source.startIndex

        while position < source.endIndex {
            // Find next tag opening
            if let tagStart = source[position...].range(of: "{{") {
                // Add text before tag
                let textEnd = tagStart.lowerBound
                if position < textEnd {
                    let text = String(source[position ..< textEnd])
                    if !text.isEmpty {
                        nodes.append(.text(text))
                    }
                }

                // Find tag closing
                let afterOpen = source.index(tagStart.upperBound, offsetBy: 0)
                guard let tagEnd = source[afterOpen...].range(of: "}}") else {
                    let pos = source.distance(from: source.startIndex, to: tagStart.lowerBound)
                    throw TemplateError.parseError(message: "Unclosed tag", position: pos)
                }

                let tagContent = String(source[afterOpen ..< tagEnd.lowerBound]).trimmingCharacters(in: .whitespaces)

                // Parse tag content
                let tagPos = source.distance(from: source.startIndex, to: tagStart.lowerBound)
                let node = try parseTag(tagContent, position: tagPos)

                if let conditional = node as? ConditionalTag {
                    let (bodyNodes, newPosition) = try parseBlock(
                        source: source,
                        start: tagEnd.upperBound,
                        endTag: "{{/if}}",
                        openingTag: "{{#if}}",
                        position: tagPos
                    )
                    nodes.append(.conditional(variable: conditional.variable, body: bodyNodes))
                    position = newPosition
                } else if let loop = node as? LoopTag {
                    let (bodyNodes, newPosition) = try parseBlock(
                        source: source,
                        start: tagEnd.upperBound,
                        endTag: "{{/each}}",
                        openingTag: "{{#each}}",
                        position: tagPos
                    )
                    nodes.append(.loop(variable: loop.variable, body: bodyNodes))
                    position = newPosition
                } else if let comment = node as? CommentTag {
                    nodes.append(.comment(comment.text))
                    position = tagEnd.upperBound
                } else if let variable = node as? VariableTag {
                    nodes.append(.variable(variable.name))
                    position = tagEnd.upperBound
                } else {
                    position = tagEnd.upperBound
                }
            } else {
                // No more tags, add remaining text
                let text = String(source[position...])
                if !text.isEmpty {
                    nodes.append(.text(text))
                }
                break
            }
        }

        return nodes
    }

    // MARK: - Tag Parsing

    private func parseTag(_ content: String, position: Int) throws -> any Tag {
        guard !content.isEmpty else {
            throw TemplateError.parseError(message: "Empty tag", position: position)
        }

        // Comment
        if content.hasPrefix("!") {
            let text = String(content.dropFirst()).trimmingCharacters(in: .whitespaces)
            return CommentTag(text: text)
        }

        // Conditional opening
        if content.hasPrefix("#if ") {
            let variable = String(content.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            try validateVariableName(variable, position: position)
            return ConditionalTag(variable: variable)
        }

        // Loop opening
        if content.hasPrefix("#each ") {
            let variable = String(content.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            try validateVariableName(variable, position: position)
            return LoopTag(variable: variable)
        }

        // Closing tags (should not appear at top level)
        if content.hasPrefix("/") {
            throw TemplateError.parseError(
                message: "Unexpected closing tag '\(content)'",
                position: position
            )
        }

        // Unknown directive
        if content.hasPrefix("#") {
            let directive = String(content.dropFirst()).split(separator: " ").first.map(String.init) ?? content
            throw TemplateError.parseError(message: "Unknown directive '\(directive)'", position: position)
        }

        // Variable
        try validateVariableName(content, position: position)
        return VariableTag(name: content)
    }

    private func parseBlock(
        source: String,
        start: String.Index,
        endTag: String,
        openingTag _: String,
        position _: Int
    ) throws -> ([TemplateNode], String.Index) {
        var nodes: [TemplateNode] = []
        var position = start
        var depth = 1

        while position < source.endIndex {
            // Find next tag
            if let tagStart = source[position...].range(of: "{{") {
                // Add text before tag
                let textEnd = tagStart.lowerBound
                if position < textEnd {
                    let text = String(source[position ..< textEnd])
                    if !text.isEmpty {
                        nodes.append(.text(text))
                    }
                }

                // Find tag closing
                let afterOpen = tagStart.upperBound
                guard let tagEnd = source[afterOpen...].range(of: "}}") else {
                    let pos = source.distance(from: source.startIndex, to: tagStart.lowerBound)
                    throw TemplateError.parseError(message: "Unclosed tag", position: pos)
                }

                let tagContent = String(source[afterOpen ..< tagEnd.lowerBound]).trimmingCharacters(in: .whitespaces)
                let tagPos = source.distance(from: source.startIndex, to: tagStart.lowerBound)

                // Check for nested blocks
                if tagContent.hasPrefix("#if ") || tagContent.hasPrefix("#each ") {
                    throw TemplateError.parseError(
                        message: "Nested blocks not supported",
                        position: tagPos
                    )
                }

                // Check for comments inside blocks
                if tagContent.hasPrefix("!") {
                    throw TemplateError.parseError(
                        message: "Comments inside blocks not supported",
                        position: tagPos
                    )
                }

                // Check for matching end tag (using trimmed content for whitespace tolerance)
                if tagContent == String(endTag.dropFirst(2).dropLast(2)) {
                    depth -= 1
                    if depth == 0 {
                        return (nodes, tagEnd.upperBound)
                    }
                } else if tagContent.hasPrefix("/") {
                    let fullTag = String(source[tagStart.lowerBound ..< tagEnd.upperBound])
                    throw TemplateError.parseError(
                        message: "Expected '\(endTag)', found '\(fullTag)'",
                        position: tagPos
                    )
                } else {
                    // Variable inside block
                    try validateVariableName(tagContent, position: tagPos)
                    nodes.append(.variable(tagContent))
                }

                position = tagEnd.upperBound
            } else {
                // No closing tag found
                let remaining = String(source[position...])
                if !remaining.isEmpty {
                    nodes.append(.text(remaining))
                }
                throw TemplateError.parseError(
                    message: "Unclosed block",
                    position: position == source.startIndex ? 0 : source.distance(from: source.startIndex, to: position)
                )
            }
        }

        throw TemplateError.parseError(
            message: "Unclosed block",
            position: position == source.startIndex ? 0 : source.distance(from: source.startIndex, to: position)
        )
    }

    private func validateVariableName(_ name: String, position: Int) throws {
        guard !name.isEmpty else {
            throw TemplateError.parseError(message: "Empty variable name", position: position)
        }
        // "\." is a special variable name referencing the current element in loops
        if name == "." { return }
        // Allow dot-paths that start with "." (e.g. ".name", ".url") for loop item field access
        let stripped = name.hasPrefix(".") ? String(name.dropFirst()) : name
        let first = stripped.first!
        guard first.isLetter || first == "_" else {
            throw TemplateError.parseError(message: "Invalid variable name '\(name)'", position: position)
        }
        for char in stripped.dropFirst() {
            guard char.isLetter || char.isNumber || char == "_" || char == "." else {
                throw TemplateError.parseError(message: "Invalid variable name '\(name)'", position: position)
            }
        }
        // Validate each component of a dot-path (e.g. "user.name" or ".name.version")
        let components = stripped.split(separator: ".")
        for component in components {
            guard let cfirst = component.first else {
                throw TemplateError.parseError(message: "Invalid variable name '\(name)'", position: position)
            }
            guard cfirst.isLetter || cfirst == "_" else {
                throw TemplateError.parseError(message: "Invalid variable name '\(name)'", position: position)
            }
            for char in component.dropFirst() {
                guard char.isLetter || char.isNumber || char == "_" else {
                    throw TemplateError.parseError(message: "Invalid variable name '\(name)'", position: position)
                }
            }
        }
    }
}

// MARK: - Tag Types

private protocol Tag: Sendable { }

private struct VariableTag: Tag { let name: String }
private struct ConditionalTag: Tag { let variable: String }
private struct LoopTag: Tag { let variable: String }
private struct CommentTag: Tag { let text: String }
