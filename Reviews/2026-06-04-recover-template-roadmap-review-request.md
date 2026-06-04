# Review Request: Recover AnvilTemplate Roadmap

## Intention

Review the recovery of an ignored local roadmap artifact from the historical `iFoundation/Packages` directory into
the real `swiftanvil-anvil-template` repository.

The old local ignored repo was one commit ahead of its remote and contained only `ROADMAP.md`. The current sibling
repository had the package implementation and CI policy, but not this roadmap.

## Builder

Codex.

## Reviewer Ask

Please review whether adding `ROADMAP.md` is appropriate and whether the recovered priorities are safe to keep:

1. TPL-001 nested loop error-path tests.
2. TPL-002 `.dictionary` support for `TemplateValue`.
3. TPL-003 parse caching.
4. v1.1 and v2.0 future roadmap notes.

Focus on whether the document is misleading, stale, or conflicts with the current package state.

## Expected Output

Return one of:

- APPROVED
- APPROVED_WITH_NOTES
- NEEDS_REVISION

Lead with the verdict and then list findings by severity.
