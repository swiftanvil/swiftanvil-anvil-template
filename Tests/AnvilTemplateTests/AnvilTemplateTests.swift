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
        if case .text(let text) = nodes[0] {
            #expect(text == "Hello, world!")
        }
    }
    
    @Test("parses variable")
    func variable() throws {
        let nodes = try parser.parse("Hello, {{name}}!")
        #expect(nodes.count == 3)
        if case .variable(let name) = nodes[1] {
            #expect(name == "name")
        }
    }
    
    @Test("parses conditional")
    func conditional() throws {
        let nodes = try parser.parse("{{#if active}}yes{{/if}}")
        #expect(nodes.count == 1)
        if case .conditional(let varName, let body) = nodes[0] {
            #expect(varName == "active")
            #expect(body.count == 1)
        }
    }
    
    @Test("parses loop")
    func loop() throws {
        let nodes = try parser.parse("{{#each items}}{{.}}{{/each}}")
        #expect(nodes.count == 1)
        if case .loop(let varName, let body) = nodes[0] {
            #expect(varName == "items")
            #expect(body.count == 1)
            if case .variable(let inner) = body[0] {
                #expect(inner == ".")
            }
        }
    }
    
    @Test("parses conditional with whitespace in closing tag")
    func conditionalWhitespaceClosing() throws {
        let nodes = try parser.parse("{{#if active}}yes{{ /if }}")
        #expect(nodes.count == 1)
        if case .conditional(let varName, let body) = nodes[0] {
            #expect(varName == "active")
            #expect(body.count == 1)
        }
    }
    
    @Test("parses loop with whitespace in closing tag")
    func loopWhitespaceClosing() throws {
        let nodes = try parser.parse("{{#each items}}{{.}}{{ /each }}")
        #expect(nodes.count == 1)
        if case .loop(let varName, let body) = nodes[0] {
            #expect(varName == "items")
            #expect(body.count == 1)
        }
    }
    
    @Test("parses comment")
    func comment() throws {
        let nodes = try parser.parse("before{{! comment }}after")
        #expect(nodes.count == 3)
        if case .comment(let text) = nodes[1] {
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
    func strictMissing() async {
        let template = try! Template("{{name}}")
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
        await #expect(throws: TemplateError.typeMismatch(variable: "items", expected: "Array", actual: "TemplateValue")) {
            _ = try template.render(context: ["items": "not an array"], mode: .strict)
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
            platforms: [.iOS(.v16)],
            products: [
                .library(name: "{{name}}", targets: ["{{name}}"]),
            ],
            dependencies: [
        {{#each dependencies}}
                .package(url: "https://github.com/swiftanvil/{{.}}", from: "1.0.0"),
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
            "dependencies": ["AnvilNetwork", "AnvilFlags"]
        ])
        
        #expect(output.contains("name: \"MyApp\""))
        #expect(output.contains("AnvilNetwork"))
        #expect(output.contains("AnvilFlags"))
    }
}
