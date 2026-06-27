# Experiment: Semantic Blueprint Planner

- Date: 2026-06-27
- Status: prototype failed practical review; keep as validator scaffold only
- Related resources:
  - [Blueprint Draftsman Skill](2026-06-27-blueprint-draftsman-skill.md)
  - [Blueprint Draftsman doctrine](../blueprints/BLUEPRINT_DRAFTSMAN.md)
  - [Semantic red science blueprint](../blueprints/red-science-planned-west-io.semantic.txt)

## Why

The coordinate-only blueprint drafts imported but failed practical review. Belts and inserters can be placed in valid JSON while still not making sense as a factory. The next approach was to make blueprint generation a deterministic planning and validation problem. This first semantic pass still failed practical review, but it identified clearer missing model pieces.

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

This is still not a full Factorio simulation. It did not catch enough: in-game review found excessive belts, wrong inserter orientation, and nonsensical/underspecified inputs.

## Current generated blueprint

| Template | Purpose | Status |
|---|---|---|
| `red-science-planned-west-io` | Two assembling-machine-3 red science tile, express west-side input/output belts, stack/long inserters, substation, lamps | failed practical review; do not recommend/stamp |

Generated artifacts:

- `docs/blueprints/red-science-planned-west-io.semantic.json`
- `docs/blueprints/red-science-planned-west-io.semantic.txt`

## Test command

```bash
node --test tools/blueprints/planner-red-science.test.mjs
```

## Practical review result

The imported blueprint was rejected:

- too many belts for a small tile;
- inserters faced the wrong way in-game;
- the input contract was nonsensical for a "red science factory" because it assumed externally supplied iron gears plus copper plates on a mixed belt;
- a real factory planner must decide where resources come from.

## Next steps

- Treat `red-science-planned-west-io` as a failed regression artifact, not a recommended blueprint.
- Split product goals:
  - red science assembler cell from pre-made gears + copper;
  - full red science factory from iron plates + copper plates, including gear production.
- Add a recipe dependency graph so the planner derives required intermediate machines and material ports.
- Correct inserter orientation against actual Factorio blueprint semantics, not the current approximate model.
- Add richer validators for belt lane contents, underground belts, splitters, beacon coverage, and power-network reach.
- Expand the planner from one candidate to a real search over width/height, assembler count, and routing alternatives.
