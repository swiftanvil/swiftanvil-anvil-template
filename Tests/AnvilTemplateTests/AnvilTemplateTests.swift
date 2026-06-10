import Foundation
import Testing
@testable import AnvilTemplate

// MARK: - Parser Tests

@Suite("TemplateParser")
struct TemplateParserTests {
    let parser = TemplateParser()

    @Test("parses plain text")
    func plainText() throws {
        let nodes = try parser.parse("Hello, world!")
        #expect(nodes.count == 1)
        if case let .text(text) = nodes[0] {
            #expect(text == "Hello, world!")
        }
    }

    @Test("parses variable")
    func variable() throws {
        let nodes = try parser.parse("Hello, {{name}}!")
        #expect(nodes.count == 3)
        if case let .variable(name) = nodes[1] {
            #expect(name == "name")
        }
    }

    @Test("parses conditional")
    func conditional() throws {
        let nodes = try parser.parse("{{#if active}}yes{{/if}}")
        #expect(nodes.count == 1)
        if case let .conditional(varName, body) = nodes[0] {
            #expect(varName == "active")
            #expect(body.count == 1)
        }
    }

    @Test("parses loop")
    func loop() throws {
        let nodes = try parser.parse("{{#each items}}{{.}}{{/each}}")
        #expect(nodes.count == 1)
        if case let .loop(varName, body) = nodes[0] {
            #expect(varName == "items")
            #expect(body.count == 1)
            if case let .variable(inner) = body[0] {
                #expect(inner == ".")
            }
        }
    }

    @Test("parses conditional with whitespace in closing tag")
    func conditionalWhitespaceClosing() throws {
        let nodes = try parser.parse("{{#if active}}yes{{ /if }}")
        #expect(nodes.count == 1)
        if case let .conditional(varName, body) = nodes[0] {
            #expect(varName == "active")
            #expect(body.count == 1)
        }
    }

    @Test("parses loop with whitespace in closing tag")
    func loopWhitespaceClosing() throws {
        let nodes = try parser.parse("{{#each items}}{{.}}{{ /each }}")
        #expect(nodes.count == 1)
        if case let .loop(varName, body) = nodes[0] {
            #expect(varName == "items")
            #expect(body.count == 1)
        }
    }

    @Test("parses comment")
    func comment() throws {
        let nodes = try parser.parse("before{{! comment }}after")
        #expect(nodes.count == 3)
        if case let .comment(text) = nodes[1] {
            #expect(text == "comment")
        }
    }

    @Test("throws on unclosed tag")
    func unclosedTag() {
        #expect(throws: TemplateError.parseError(message: "Unclosed tag", position: 0)) {
            _ = try parser.parse("{{name")
        }
    }

    @Test("throws on empty tag")
    func emptyTag() {
        #expect(throws: TemplateError.parseError(message: "Empty tag", position: 0)) {
            _ = try parser.parse("{{}}")
        }
    }

    @Test("throws on unknown directive")
    func unknownDirective() {
        #expect(throws: TemplateError.parseError(message: "Unknown directive 'foo'", position: 0)) {
            _ = try parser.parse("{{#foo}}")
        }
    }

    @Test("throws on unexpected closing tag")
    func unexpectedClosing() {
        #expect(throws: TemplateError.parseError(message: "Unexpected closing tag '/if'", position: 0)) {
            _ = try parser.parse("{{/if}}")
        }
    }

    @Test("throws on unclosed conditional")
    func unclosedConditional() {
        #expect(throws: TemplateError.parseError(message: "Unclosed block", position: 9)) {
            _ = try parser.parse("{{#if x}}content")
        }
    }

    @Test("throws on nested blocks")
    func nestedBlocks() {
        #expect(throws: TemplateError.parseError(message: "Nested blocks not supported", position: 9)) {
            _ = try parser.parse("{{#if x}}{{#if y}}{{/if}}{{/if}}")
        }
    }

    @Test("throws on mismatched block")
    func mismatchedBlock() {
        #expect(throws: TemplateError.parseError(message: "Expected '{{/if}}', found '{{/each}}'", position: 9)) {
            _ = try parser.parse("{{#if x}}{{/each}}")
        }
    }

    @Test("throws on comment inside block")
    func commentInBlock() {
        #expect(throws: TemplateError.parseError(message: "Comments inside blocks not supported", position: 9)) {
            _ = try parser.parse("{{#if x}}{{! comment}}{{/if}}")
        }
    }

    @Test("throws on invalid variable name")
    func invalidVariable() {
        #expect(throws: TemplateError.parseError(message: "Invalid variable name '123'", position: 0)) {
            _ = try parser.parse("{{123}}")
        }
    }
}

// MARK: - Renderer Tests

@Suite("TemplateRenderer")
struct TemplateRendererTests {
    let renderer = TemplateRenderer()

    @Test("renders variable substitution")
    func variableSub() throws {
        let template = try Template("Hello, {{name}}!")
        let output = try template.render(context: ["name": "World"])
        #expect(output == "Hello, World!")
    }

    @Test("renders multiple variables")
    func multipleVars() throws {
        let template = try Template("{{greeting}}, {{name}}!")
        let output = try template.render(context: ["greeting": "Hi", "name": "Swift"])
        #expect(output == "Hi, Swift!")
    }

    @Test("renders conditional when true")
    func conditionalTrue() throws {
        let template = try Template("{{#if active}}yes{{/if}}")
        let output = try template.render(context: ["active": true])
        #expect(output == "yes")
    }

    @Test("renders conditional when false")
    func conditionalFalse() throws {
        let template = try Template("{{#if active}}yes{{/if}}")
        let output = try template.render(context: ["active": false])
        #expect(output == "")
    }

    @Test("renders loop")
    func loop() throws {
        let template = try Template("{{#each items}}{{.}} {{/each}}")
        let output = try template.render(context: ["items": ["a", "b", "c"]])
        #expect(output == "a b c ")
    }

    @Test("renders comments as empty")
    func comment() throws {
        let template = try Template("before{{! hidden }}after")
        let output = try template.render(context: [:])
        #expect(output == "beforeafter")
    }

    @Test("strict mode throws on missing variable")
    func strictMissing() async throws {
        let template = try Template("{{name}}")
        await #expect(throws: TemplateError.missingVariable("name")) {
            _ = try template.render(context: [:], mode: .strict)
        }
    }

    @Test("lenient mode renders empty for missing")
    func lenientMissing() throws {
        let template = try Template("{{name}}")
        let output = try template.render(context: [:], mode: .lenient)
        #expect(output == "")
    }

    @Test("renders int as string")
    func intRender() throws {
        let template = try Template("Count: {{count}}")
        let output = try template.render(context: ["count": 42])
        #expect(output == "Count: 42")
    }

    @Test("renders bool as string")
    func boolRender() throws {
        let template = try Template("Active: {{active}}")
        let output = try template.render(context: ["active": true])
        #expect(output == "Active: true")
    }

    @Test("conditional with string truthy")
    func stringTruthy() throws {
        let template = try Template("{{#if name}}Hello{{/if}}")
        let output = try template.render(context: ["name": "Swift"])
        #expect(output == "Hello")
    }

    @Test("conditional with string falsy")
    func stringFalsy() throws {
        let template = try Template("{{#if name}}Hello{{/if}}")
        let output = try template.render(context: ["name": ""])
        #expect(output == "")
    }

    @Test("loop throws type mismatch on non-array")
    func loopTypeMismatch() async throws {
        let template = try Template("{{#each items}}{{.}}{{/each}}")
        await #expect(throws: TemplateError.typeMismatch(
            variable: "items",
            expected: "Array",
            actual: "TemplateValue"
        )) {
            _ = try template.render(context: ["items": "not an array"], mode: .strict)
        }
    }

    @Test("renders dictionary dot-path variable")
    func dictionaryDotPath() throws {
        let template = try Template("{{user.name}} — {{user.email}}")
        let output = try template.render(context: [
            "user": ["name": "Swift", "email": "swift@anvil.dev"]
        ])
        #expect(output == "Swift — swift@anvil.dev")
    }

    @Test("renders loop with dictionary elements")
    func loopWithDictionaries() throws {
        let template = try Template("{{#each deps}}{{.name}}:{{.version}} {{/each}}")
        let output = try template.render(context: [
            "deps": [
                ["name": "AnvilNetwork", "version": "1.0.0"],
                ["name": "AnvilFlags", "version": "1.1.0"]
            ]
        ])
        #expect(output == "AnvilNetwork:1.0.0 AnvilFlags:1.1.0 ")
    }

    @Test("renders nested dictionary dot-path")
    func nestedDictionary() throws {
        let template = try Template("{{config.build.debug}}")
        let output = try template.render(context: [
            "config": ["build": ["debug": true]]
        ])
        #expect(output == "true")
    }

    @Test("dictionary conditional is truthy when non-empty")
    func dictionaryConditionalTruthy() throws {
        let template = try Template("{{#if user}}found{{/if}}")
        let output = try template.render(context: ["user": ["name": "Swift"]])
        #expect(output == "found")
    }

    @Test("dictionary conditional is falsy when empty")
    func dictionaryConditionalFalsy() throws {
        let template = try Template("{{#if user}}found{{/if}}")
        let output = try template.render(context: ["user": [String: String]()])
        #expect(output == "")
    }

    @Test("missing dot-path returns empty in lenient mode")
    func missingDotPathLenient() throws {
        let template = try Template("{{user.missing}}")
        let output = try template.render(context: ["user": ["name": "Swift"]], mode: .lenient)
        #expect(output == "")
    }

    @Test("missing dot-path throws in strict mode")
    func missingDotPathStrict() async throws {
        let template = try Template("{{user.missing}}")
        await #expect(throws: TemplateError.missingVariable("user.missing")) {
            _ = try template.render(context: ["user": ["name": "Swift"]], mode: .strict)
        }
    }
}

// MARK: - Integration Tests

@Suite("Integration")
struct IntegrationTests {
    @Test("Package.swift-like template")
    func packageTemplate() throws {
        let source = """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "{{name}}",
            platforms: [.iOS(.v18)],
            products: [
                .library(name: "{{name}}", targets: ["{{name}}"]),
            ],
            dependencies: [
        {{#each dependencies}}
                .package(url: "{{.url}}", from: "{{.version}}"),
        {{/each}}
            ],
            targets: [
                .target(name: "{{name}}"),
            ]
        )
        """

        let template = try Template(source)
        let output = try template.render(context: [
            "name": "MyApp",
            "dependencies": [
                ["url": "https://github.com/swiftanvil/AnvilNetwork", "version": "1.0.0"],
                ["url": "https://github.com/swiftanvil/AnvilFlags", "version": "1.1.0"]
            ]
        ])

        #expect(output.contains("name: \"MyApp\""))
        #expect(output.contains("AnvilNetwork"))
        #expect(output.contains("AnvilFlags"))
        #expect(output.contains("from: \"1.0.0\""))
        #expect(output.contains("from: \"1.1.0\""))
    }
}
