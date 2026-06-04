# AnvilTemplate

A lightweight template engine for the swiftanvil project. Generates boilerplate code from template strings with variable substitution, conditionals, and loops.

## Template Syntax

### Variable Substitution

```
Hello, {{name}}!
```

### Conditionals

```
{{#if useSwiftUI}}
import SwiftUI
{{/if}}
```

### Loops

```
{{#each dependencies}}
    .package(url: "https://github.com/swiftanvil/{{.}}", from: "1.0.0"),
{{/each}}
```

Inside a loop, `{{.}}` references the current element.

### Comments

```
{{! This will not appear in output }}
```

## Supported Value Types

| Type | Render Behavior |
|------|-----------------|
| `String` | Rendered as-is |
| `Bool` | `true` → "true", `false` → "false". Used in `#if` |
| `Int`, `Double` | String representation |
| `[String]` | Iterated by `#each`. Inside loop, `{{.}}` is current element |
| `nil` / missing | Strict mode: error. Lenient mode: empty string |

## Usage

```swift
import AnvilTemplate

// From string
let template = try Template("Hello, {{name}}!")
let output = try template.render(context: ["name": "World"])
// "Hello, World!"

// From file
let template = try Template(contentsOf: URL(fileURLWithPath: "template.txt"))

// Strict mode — fails fast on missing variables
let template = try Template("{{name}} {{version}}")
try template.render(context: ["name": "App"], mode: .strict)
// throws TemplateError.missingVariable("version")

// With loop
let template = try Template("{{#each items}}{{.}} {{/each}}")
let output = try template.render(context: ["items": ["a", "b", "c"]])
// "a b c "
```

## Error Handling

All parser errors throw `TemplateError.parseError(message:position:)`:

| Case | Example | Error |
|------|---------|-------|
| Unclosed tag | `{{name` | "Unclosed tag at position N" |
| Empty tag | `{{}}` | "Empty tag at position N" |
| Unknown directive | `{{#foo}}` | "Unknown directive 'foo'" |
| Unexpected closing | `{{/if}}` without `{{#if}}` | "Unexpected closing tag '/if'" |
| Unclosed block | `{{#if x}}...` (no `{{/if}}`) | "Unclosed block" |
| Mismatched block | `{{#if x}}...{{/each}}` | "Expected '{{/if}}', found '{{/each}}'" |
| Nested blocks | `{{#if a}}{{#if b}}` | "Nested blocks not supported" |
| Invalid variable | `{{123}}` | "Invalid variable name '123'" |
| Comment in block | `{{#if x}}{{! c}}{{/if}}` | "Comments inside blocks not supported" |

Render errors:
- `TemplateError.missingVariable("name")` — variable not found in strict mode
- `TemplateError.typeMismatch(variable:expected:actual:)` — loop variable is not an array

## Platforms

iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+

## Dependencies

None. Pure Swift + Foundation.

## Architecture

```
AnvilTemplate
├── Core/
│   ├── Template.swift           # Parse + render entry point
│   ├── TemplateContext.swift    # Variable storage
│   ├── TemplateError.swift      # Parse/render errors
│   └── RenderMode.swift         # .strict / .lenient
├── AST/
│   ├── TemplateNode.swift       # AST enum
│   └── TemplateValue.swift      # Typed renderable values
├── Parser/
│   └── TemplateParser.swift     # String → AST
└── Renderer/
    └── TemplateRenderer.swift   # AST + Context → String
```

The parser and renderer are separate public types for testability.
