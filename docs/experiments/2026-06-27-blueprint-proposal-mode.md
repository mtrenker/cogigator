# Experiment: Blueprint Proposal Mode

- Date: 2026-06-27
- Status: prototype
- Related commits: pending
- Related resources:
  - [Cognition Network Synthesis](2026-06-27-industrial-cognition-synthesis.md)
  - [Live local snapshot runbook](2026-06-27-live-local-snapshot-runbook.md)

## Question

Can Cogigator move from diagnosis to **proposal-only blueprint drafting** without adding a world mutation path?

The desired player flow is:

```text
observe local worksite
  -> identify bottleneck
  -> draft a Factorio blueprint proposal
  -> human inspects/imports/places it manually
```

## Safety boundary

Blueprint proposal mode is not construction automation.

Allowed:

- read fixture or `live-local` snapshots;
- produce a draft Factorio blueprint string;
- include a human-readable summary and caution;
- require manual human inspection and placement.

Forbidden:

- placing entities directly;
- issuing RCON build commands;
- driving construction bots;
- writing to the Factorio world beyond the already-local snapshot export file;
- implying a proposal has been applied.

## Prototype API

Bridge endpoint:

```text
POST /blueprint-proposal
{
  "scenarioId": "starved-assembler" | "live-local" | ...,
  "variantId": "cognition-flow" | "capacity-vector",
  "intent": "optional build goal"
}
```

Response shape:

```text
schemaVersion: cogigator.blueprint-proposal.v1
mode: proposal-only
mutation: false
humanApprovalRequired: true
primaryFindingCode: <finding code>
summary: <what the draft tries to do>
caution: <what the human must verify>
blueprintJson: <Factorio blueprint JSON>
blueprintString: <Factorio import string or null>
```

Pi tool/command:

```text
cogigator_blueprint_proposal(scenarioId, variantId, intent?)
/cogigator-blueprint [scenarioId] [variantId] [intent...]
```

## Current draft coverage

| Finding | Prototype behavior |
|---|---|
| `input-starved` / `belt-starved` | Drafts a tiny belt + inserter feed starter near the subject machine. |
| `output-blocked` / `belt-backed-up` | Drafts a tiny output belt + inserter unblocking starter near the subject machine. |
| Other findings | Returns no blueprint string and asks for manual planning. |

## Acceptance criteria

- Bridge tests prove the proposal response is `proposal-only`, `mutation:false`, and decodable as a Factorio blueprint string.
- Pi displays the summary, caution, and blueprint string without claiming it was applied.
- Human can import the string manually into Factorio.
- The proposal is clearly labelled as a draft/starter, not an authoritative fix.

## Next tests

1. Run fixture proposal:

   ```bash
   curl -sS -H 'content-type: application/json' \
     -d '{"scenarioId":"starved-assembler","variantId":"capacity-vector","intent":"fix input starvation"}' \
     http://127.0.0.1:8787/blueprint-proposal | jq '{primaryFindingCode,summary,caution,blueprintString}'
   ```

2. Run Pi command:

   ```text
   /cogigator-blueprint starved-assembler capacity-vector fix input starvation
   ```

3. Import the blueprint string into a local Factorio test save and inspect it before placing.

## Timeline summary

Cogigator now has its first proposal-only bridge endpoint: it can draft a small Factorio blueprint string from a diagnosis while preserving the hard boundary that only the human imports and places it.
