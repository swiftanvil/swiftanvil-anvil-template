# AnvilTemplate Roadmap

> Current version: 1.0.0 | PMS: 78 (B) | Next review: 2026-06-18

---

## Now (v1.0.x) — Active

- [ ] **TPL-001**: Add tests for nested loop error paths (impact: 3, effort: small)
- [ ] **TPL-002**: Add `.dictionary` to `TemplateValue` (impact: 8, effort: medium)
  - This unblocks AnvilDocs DOC-001 (template-based landing page)
- [ ] **TPL-003**: Template parse caching — parse once, render many (impact: 5, effort: small)

## Next (v1.1.0) — Planned

- [ ] Partial templates `{{> header}}`
- [ ] `{{#unless}}` directive (inverse of `{{#if}}`)
- [ ] Strict mode by default option in `Template.init`

## Later (v2.0.0) — Future

- [ ] Async template rendering for I/O-bound partials
- [ ] Template compilation to Swift source code (zero-parse overhead)
- [ ] IDE support: syntax highlighting, autocomplete, diagnostics

---

## Improvement History

| Date | Version | Change | PMS Delta |
|------|---------|--------|-----------|
| 2026-06-03 | 1.0.0 | Initial release | — |

---

## Why These Priorities?

1. **`.dictionary` (TPL-002)** is highest impact because it unblocks AnvilDocs and enables real-world template
   patterns such as nested data and configuration objects.

2. **Parse caching (TPL-003)** is a quick win for performance because every template currently re-parses on every
   render.

3. **Partials (v1.1.0)** enable template composition, which is essential for any non-trivial project.

4. **Compilation (v2.0.0)** is the long-term performance goal: turn templates into Swift code at build time for zero
   runtime parse overhead.
