# Experiment: Semantic Blueprint Planner

- Date: 2026-06-27
- Status: first deterministic semantic planner prototype
- Related resources:
  - [Blueprint Draftsman Skill](2026-06-27-blueprint-draftsman-skill.md)
  - [Blueprint Draftsman doctrine](../blueprints/BLUEPRINT_DRAFTSMAN.md)
  - [Semantic red science blueprint](../blueprints/red-science-planned-west-io.semantic.txt)

## Why

The coordinate-only blueprint drafts imported but failed practical review. Belts and inserters can be placed in valid JSON while still not making sense as a factory. The next approach is to make blueprint generation a deterministic planning and validation problem.

## Prototype

Added a small semantic Factorio model and red-science planner:

```bash
node tools/blueprints/planner-red-science.mjs
```

The planner receives requirements and optional surface information:

```bash
node tools/blueprints/planner-red-science.mjs \
  --requirements requirements.json \
  --surface surface.json

# or consume the live-local snapshot exported by the Factorio mod
node tools/blueprints/planner-red-science.mjs \
  --snapshot /path/to/script-output/cogigator/live-snapshot.json
```

The current surface schema is intentionally small:

```json
{
  "source": "synthetic-empty-surface",
  "blockedTiles": [{ "x": 2, "y": 0 }]
}
```

If a planned entity overlaps a blocked tile, the candidate is rejected. The Factorio mod now includes a bounded `surfaceScan` block in `/cogigator-export-snapshot` output so the planner can consume live-local worksite tile data without mutating the world.

## What is validated

The new validator checks more than entity counts:

- belt graph continuity, including external tile ports;
- inserter pickup and drop points from direction and reach;
- input inserters pick from belts and drop into assemblers;
- output inserters pick from assemblers and drop onto belts;
- assembler recipe assignment;
- coarse collision with blocked surface tiles;
- tileable west-side I/O ports.

This is still not a full Factorio simulation, but it catches the class of mistakes that made the first red-science drafts useless.

## Current generated blueprint

| Template | Purpose | Status |
|---|---|---|
| `red-science-planned-west-io` | Two assembling-machine-3 red science tile, express west-side input/output belts, stack/long inserters, substation, lamps | semantically validated by tool; needs in-game review |

Generated artifacts:

- `docs/blueprints/red-science-planned-west-io.semantic.json`
- `docs/blueprints/red-science-planned-west-io.semantic.txt`

## Test command

```bash
node --test tools/blueprints/planner-red-science.test.mjs
```

## Next steps

- Import the semantic blueprint in Factorio and perform practical review.
- Feed it with copper plates and iron gear wheels and confirm red science reaches the output belt.
- Extend the surface input to consume bridge live-local worksite tile/entity data.
- Add richer validators for belt lane contents, underground belts, splitters, beacon coverage, and power-network reach.
- Expand the planner from one candidate to a real search over width/height, assembler count, and routing alternatives.
