# Blueprint Draftsman Doctrine

Cogigator blueprint work must not freehand blueprint strings from prose. It must use an explicit layout model, deterministic encoding, and a validation checklist.

## Required workflow

1. Restate constraints:
   - recipe/product;
   - assembler tier/count;
   - belt tier;
   - input side and output side;
   - power/lights requirement;
   - maximum footprint, if any;
   - tileable vs one-off.
2. Draw a coordinate grid in text before encoding.
3. Generate the blueprint from structured coordinates.
4. Validate the layout before returning it.
5. Return:
   - blueprint string;
   - footprint;
   - I/O contract;
   - known limitations.

## Hard rules

- Do not invent blueprint strings directly.
- Do not claim the blueprint was placed or tested unless it was imported in Factorio.
- Prefer small, named templates over ad-hoc spatial reasoning.
- If constraints conflict, stop and ask.
- For Cogigator, blueprint drafting remains proposal-only: human import and placement are required.

## Validation checklist

- Every assembler has the requested recipe.
- Belt directions are explicit and consistent.
- Inserter pickup/drop intent is documented.
- Input and output sides match the user request.
- Power poles cover all machines/inserters/lights, as far as the template claims.
- There are no orphan belts, unrelated entities, or unexplained decorations.
- The blueprint has a stated footprint.
