# Runbook: Industrial Cognition A/B Local Demo

- Date: 2026-06-26
- Status: draft
- Objective: demonstrate the full A/B loop locally using Task 007 bridge stub, Task 004 (`cognition-flow`) and Task 005 (`capacity-vector`) fixtures, and Task 008 Pi tools.
- Experiment ID: `industrial-cognition-ab`

## 1) Prerequisites

- Node.js 18+
- `jq` and `curl` for readability (optional but recommended)
- A local terminal in this repo root: `/home/martin/dev/cogigator`
- No Factorio runtime required for this task because this is a fixture-based demo.

## 2) Start the local bridge stub (Task 007)

```bash
cd /home/martin/dev/cogigator
PORT=8787 node bridge/server.mjs
```

Keep the process running.

Optional endpoint health check:

```bash
curl -sS http://127.0.0.1:8787/health | jq
```

Expected shape:

```json
{
  "schemaVersion": "cogigator.bridge.v1",
  "requestId": "...",
  "serverTime": "...",
  "status": "ok"
}
```

## 3) Discover both available variants (switch between A/B)

Use the experiment metadata endpoint to confirm both variant modules are available:

```bash
curl -sS http://127.0.0.1:8787/experiments/current | jq
```

Expected output keys:

- `experimentId: industrial-cognition-ab`
- `variants` includes `cognition-flow` and `capacity-vector`
- `scenarios` includes the six closed enum scenario IDs.

Minimal extraction:

```bash
curl -sS http://127.0.0.1:8787/experiments/current |
  jq '{experimentId, variants: (.variants|map({variantId, variantLabel, stationKind})), scenarios}'
```

Expected:

```json
{
  "experimentId": "industrial-cognition-ab",
  "variants": [
    {"variantId": "cognition-flow", "variantLabel": "Sightline + Cognition Flow", "stationKind": "core"},
    {"variantId": "capacity-vector", "variantLabel": "Field Station + Capacity Vector", "stationKind": "field-station"}
  ],
  "scenarios": ["starved-assembler", "blocked-output", "missing-fluid", "low-power", "under-computed", "dense-cell-truncated"]
}
```

## 4) Query variant snapshots by id (Task 004 / Task 005)

Replace `<SCENARIO>` and `<VARIANT>`.

```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=<SCENARIO>&variantId=<VARIANT>" | jq
```

- `<VARIANT>=cognition-flow` → Variant A module view from Task 004
- `<VARIANT>=capacity-vector` → Variant B module view from Task 005

### Happy-path transcript (Scenario: `starved-assembler`)

```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=starved-assembler&variantId=cognition-flow" | jq '{scenarioId,variantId:.variant.variantId,stationKind:.station.stationKind,cognition:(.cognition|{capacities: [.capacities|.[]|{key,value,limit,satisfied,bottleneck,note}],degradation})'
```

```json
{
  "scenarioId": "starved-assembler",
  "variantId": "cognition-flow",
  "stationKind": "core",
  "cognition": {
    "capacities": [
      {"key":"sightline","value":1024,"limit":1024,"satisfied":true,"bottleneck":false,"note":"Entire worksite is visible."},
      {"key":"cognitionFlow","value":24,"limit":20,"satisfied":true,"bottleneck":false,"note":"Flow meets deterministic report demand."},
      {"key":"cognitionBuffer","value":80,"limit":60,"satisfied":true,"bottleneck":false,"note":"Buffer has enough reserve for this report."},
      {"key":"memory","value":8,"limit":6,"satisfied":true,"bottleneck":false,"note":"Recent observations are retained."}
    ],
    "degradation": {"degraded":false,"level":"none","flags":{"overloaded":false},"reasons":[],"effects":[]}
  }
}
```

```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=starved-assembler&variantId=capacity-vector" | jq '{scenarioId,variantId:.variant.variantId,stationKind:.station.stationKind,cognition:(.cognition|{capacities: [.capacities|.[]|{key,value,limit,satisfied,bottleneck,note}],degradation})'
```

```json
{
  "scenarioId": "starved-assembler",
  "variantId": "capacity-vector",
  "stationKind": "field-station",
  "cognition": {
    "capacities": [
      {"key":"scan","value":1024,"limit":1024,"satisfied":true,"bottleneck":false,"note":"Scan budget covers the worksite."},
      {"key":"attention","value":3,"limit":2,"satisfied":true,"bottleneck":false,"note":"One station slot remains free."},
      {"key":"memory","value":8,"limit":6,"satisfied":true,"bottleneck":false,"note":"Recent observations are retained."},
      {"key":"planning","value":1,"limit":1,"satisfied":true,"bottleneck":false,"note":"Planning gate is enabled for read-only advice."}
    ],
    "degradation": {"degraded":false,"level":"none","flags":{},"reasons":[],"effects":[]}
  }
}
```

## 5) Call deterministic analyze endpoint (Task 007) — same tool semantics for both variants

```bash
curl -sS -H 'content-type: application/json' -d '{"scenarioId":"starved-assembler","variantId":"cognition-flow","question":"What is wrong?"}' http://127.0.0.1:8787/analyze | jq
curl -sS -H 'content-type: application/json' -d '{"scenarioId":"starved-assembler","variantId":"capacity-vector","question":"What is wrong?"}' http://127.0.0.1:8787/analyze | jq
```

Both calls return `cogigator.analyze.v1`, `findings[]`, deterministic citations, `primaryFindingCode`, and `cognitionExplanation`.

```bash
curl -sS -H 'content-type: application/json' -d '{"scenarioId":"starved-assembler","variantId":"cognition-flow","question":"What is wrong?"}' http://127.0.0.1:8787/analyze | jq '{variantId:.variantId,primaryFindingCode,citations,truncated}'
```

```json
{
  "variantId": "cognition-flow",
  "primaryFindingCode": "input-starved",
  "citations": {"stationId":"core-1","tick":123456,"findingCodes":["input-starved","belt-starved"]},
  "truncated": false
}
```

```bash
curl -sS -H 'content-type: application/json' -d '{"scenarioId":"starved-assembler","variantId":"capacity-vector","question":"What is wrong?"}' http://127.0.0.1:8787/analyze | jq '{variantId:.variantId,primaryFindingCode,citations,truncated}'
```

```json
{
  "variantId": "capacity-vector",
  "primaryFindingCode": "input-starved",
  "citations": {"stationId":"field-station-1","tick":123456,"findingCodes":["input-starved","belt-starved"]},
  "truncated": false
}
```

## 6) Run Pi tools from Task 008 (project-local extension)

Load this project extension inside Pi after trust:
- `/home/martin/dev/cogigator/.pi/extensions/cogigator/index.ts`

Then run these commands in Pi:

- `/cogigator-experiment` → prints experiment id, both variants, and scenario ids from `/experiments/current`.
- `/cogigator-snapshot starved-assembler cognition-flow`
- `/cogigator-snapshot starved-assembler capacity-vector`
- `/cogigator-status`

For LLM-facing calls, the tools are the same and variant-agnostic:
- `cogigator_status()`
- `cogigator_snapshot({scenarioId:"starved-assembler", variantId:"cognition-flow"})`
- `cogigator_snapshot({scenarioId:"starved-assembler", variantId:"capacity-vector"})`
- `cogigator_analyze({scenarioId:"starved-assembler", variantId:"capacity-vector", question:"What is wrong?"})`

Use different `variantId` values to switch between Variant A and Variant B in the same session.

## 7) A/B loop completion checklist

1. Start bridge.
2. Run `/experiments/current` and confirm both variant IDs.
3. Fetch `/snapshot` for `starved-assembler` with `cognition-flow`.
4. Fetch `/snapshot` for `starved-assembler` with `capacity-vector`.
5. Call `/analyze` (or `cogigator_analyze`) for both variants.
6. Compare `findings`, capacities, and `degradation` outputs.

If all five outputs are reproducible, the local A/B loop is complete.
