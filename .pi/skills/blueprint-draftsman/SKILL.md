---
name: blueprint-draftsman
description: Use when creating Factorio blueprint strings or layout plans. Forces explicit grid layout, deterministic generation, and validation instead of freehand blueprint strings.
---

# Blueprint Draftsman

When asked for a Factorio blueprint:

1. Clarify or infer constraints: recipe, assembler tier/count, belt tier, I/O side, power/lights, footprint, tileability.
2. First provide 1-3 ASCII/layout concepts with tradeoffs. Do not jump directly to a blueprint string unless the user explicitly asks to skip review.
3. Let the user choose or adjust a concept.
4. Never freehand a blueprint string. Use a deterministic script/template or write explicit JSON from the approved layout.
5. Provide a preview/coordinate grid before or alongside the string.
6. Validate: recipe set, directions explicit, I/O side, power coverage, no orphan belts. For production layouts, structural validation is insufficient: inserter pickup/drop and belt lane flow must be semantically checked or clearly marked unverified.
7. Label output as proposal-only unless tested in Factorio.

If the user rejects a generated blueprint as weird, treat that as a failed validation. Revise the approach; do not argue that the string is technically valid. Prefer golden primitives or human-approved templates over repeated coordinate-only generation.

Project helper:

```bash
node tools/blueprints/draftsman.mjs red-science-same-side
```

Reference doctrine: `docs/blueprints/BLUEPRINT_DRAFTSMAN.md`.
