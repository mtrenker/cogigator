# Experiment: Blueprint Draftsman Skill

- Date: 2026-06-27
- Status: prototype failed validation; needs different approach
- Related resources:
  - [Blueprint Proposal Mode](2026-06-27-blueprint-proposal-mode.md)
  - [Blueprint Draftsman doctrine](../blueprints/BLUEPRINT_DRAFTSMAN.md)
  - [Red science same-side v2 blueprint](../blueprints/red-science-same-side.v2.txt)

## Why

Direct LLM-generated Factorio blueprint strings are too unreliable for layout constraints. They may be technically importable while still being awkward, non-compact, or inconsistent with the requested I/O side.

The first deterministic draftsman pass improved importability and compactness, but still failed actual layout validation: belts and inserters did not make practical Factorio sense. Blueprint work needs a stronger procedure than coordinate generation alone.

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

Current templates:

| Template | Purpose | Status |
|---|---|---|
| `red-science-same-side` | Four automation science assemblers, west-side input/output, power, lights | failed: visually sparse/awkward after import |
| `red-science-endgame-same-side-c` | Four endgame assemblers, express belts, west-side I/O | failed: still too tall/sparse and awkward |
| `red-science-endgame-same-side-c3-small` | Two endgame assemblers, compact same-side I/O | imported and more compact, but failed practical validation: belts/inserters still do not make sense |

## Skill rules

The local skill file is at:

```text
.pi/skills/blueprint-draftsman/SKILL.md
```

Core rule:

> Never freehand blueprint strings. Generate from an explicit coordinate model and validate constraints.

New lesson:

> Structural validation is not enough. A blueprint helper must reason with Factorio connection semantics or use known-good primitives/golden templates.

## Current limitations

- Validation is structural, not a full Factorio simulation.
- Inserter pickup/drop and belt lane behavior are not validated.
- Generated coordinate templates can still be bad even when importable.
- This skill is proposal-only; humans still import/place blueprints manually.

## Next steps

- Pause coordinate-only generation for production layouts.
- Try a different approach:
  - build from known-good Factorio primitives;
  - add semantic validators for inserter pickup/drop and belt lane flow;
  - or use human-approved golden templates as seeds, then transform/parameterize them.
- Keep the failed red science artifacts as regression examples:
  - `docs/blueprints/red-science-same-side.v2.txt`
  - `docs/blueprints/red-science-endgame-same-side-c3-small.failed.txt`
- Do not wire these templates into blueprint proposal mode as recommended outputs.
