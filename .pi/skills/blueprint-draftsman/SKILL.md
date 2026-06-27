---
name: blueprint-draftsman
description: Use when creating Factorio blueprint strings or layout plans. Forces explicit grid layout, deterministic generation, and validation instead of freehand blueprint strings.
---

# Blueprint Draftsman

When asked for a Factorio blueprint:

1. Clarify or infer constraints: recipe, assembler tier/count, belt tier, I/O side, power/lights, footprint, tileability.
2. Never freehand a blueprint string. Use a deterministic script/template or write explicit JSON first.
3. Provide a coordinate grid or entity table before/alongside the string.
4. Validate: recipe set, directions explicit, I/O side, power coverage, no orphan belts.
5. Label output as proposal-only unless tested in Factorio.

Project helper:

```bash
node tools/blueprints/draftsman.mjs red-science-same-side
```

Reference doctrine: `docs/blueprints/BLUEPRINT_DRAFTSMAN.md`.
