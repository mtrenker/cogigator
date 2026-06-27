# Blueprint Draftsman Doctrine

Cogigator blueprint work must not freehand blueprint strings from prose. It must use an explicit layout model, deterministic encoding, and a validation checklist.

## Required workflow

Blueprint design must be conversational and staged. The goal is to reduce player decision fatigue, not replace it with one giant opaque string.

1. Restate constraints:
   - recipe/product;
   - assembler tier/count;
   - belt tier;
   - input side and output side;
   - power/lights requirement;
   - maximum footprint, if any;
   - tileable vs one-off.
2. Produce 1-3 **layout concepts**, not blueprint strings:
   - tiny ASCII sketch;
   - footprint;
   - I/O contract;
   - tradeoffs.
3. Ask the user to choose or adjust one concept.
4. Only after concept approval, generate structured coordinates.
5. Render a human-readable preview from the coordinates.
6. Validate the layout before returning a Factorio blueprint string.
7. Return:
   - blueprint string;
   - preview;
   - footprint;
   - I/O contract;
   - known limitations.

## Hard rules

- Do not invent blueprint strings directly.
- Do not output a blueprint string before the user approves an ASCII/layout concept, unless the user explicitly asks to skip review.
- Do not claim the blueprint was placed or tested unless it was imported in Factorio.
- Prefer small, named templates and reusable primitives over ad-hoc spatial reasoning.
- Coordinate-only generation is not enough for production layouts; require semantic checks or human-approved golden primitives before recommending a blueprint.
- If constraints conflict, stop and ask.
- For Cogigator, blueprint drafting remains proposal-only: human import and placement are required.

## Conversational design pattern

Use this loop for layout work:

```text
constraints -> concepts -> user picks one -> coordinate model -> preview -> blueprint string -> in-game feedback -> revision
```

When the user says a design is weird, do not defend it. Treat the screenshot/import feedback as a failed validation and revise the model.

## Validation checklist

- Every assembler has the requested recipe.
- Belt directions are explicit and consistent.
- Inserter pickup/drop intent is documented and either semantically validated or explicitly marked unverified.
- Belt lane flow and direction are semantically validated or explicitly marked unverified.
- Input and output sides match the user request.
- Power poles cover all machines/inserters/lights, as far as the template claims.
- There are no orphan belts, unrelated entities, or unexplained decorations.
- The blueprint has a stated footprint.
