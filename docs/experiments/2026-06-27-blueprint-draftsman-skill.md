# Experiment: Blueprint Draftsman Skill

- Date: 2026-06-27
- Status: prototype
- Related resources:
  - [Blueprint Proposal Mode](2026-06-27-blueprint-proposal-mode.md)
  - [Blueprint Draftsman doctrine](../blueprints/BLUEPRINT_DRAFTSMAN.md)
  - [Red science same-side v2 blueprint](../blueprints/red-science-same-side.v2.txt)

## Why

Direct LLM-generated Factorio blueprint strings are too unreliable for layout constraints. They may be technically importable while still being awkward, non-compact, or inconsistent with the requested I/O side.

Blueprint work needs a stronger procedure: explicit grid first, deterministic generation second, validation before returning a string.

## Prototype

Added a small draftsman helper:

```bash
node tools/blueprints/draftsman.mjs red-science-same-side
```

It returns:

- a named template;
- footprint;
- I/O contract;
- validation result;
- Factorio blueprint JSON;
- Factorio blueprint string.

Current template:

| Template | Purpose | Status |
|---|---|---|
| `red-science-same-side` | Four automation science assemblers, west-side input/output, power, lights | generated and structurally validated; needs in-game import review |

## Skill rules

The local skill file is at:

```text
.pi/skills/blueprint-draftsman/SKILL.md
```

Core rule:

> Never freehand blueprint strings. Generate from an explicit coordinate model and validate constraints.

## Current limitations

- Validation is structural, not a full Factorio simulation.
- Inserter reach/orientation still needs in-game import review.
- Only one template exists.
- This skill is proposal-only; humans still import/place blueprints manually.

## Next steps

- Import `docs/blueprints/red-science-same-side.v2.txt` into Factorio and inspect.
- If the layout is good, add it as a named template for blueprint proposal mode.
- If not, adjust the coordinate model and rerun the generator.
- Add more deterministic templates: green circuits, belt balancer stubs, smelting columns, mall cells.
