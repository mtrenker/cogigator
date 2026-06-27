# Spike Contract: Industrial Cognition A/B (`2026-06-26-industrial-cognition-ab`)

This document is the **authoritative implementation contract** for the first
shared-substrate Cogigator A/B spike. It freezes the shapes that multiple
agents must agree on so that Tasks 002–013 can be implemented **without reading
the planning chat or re-deriving field names** from the source plans.

If a field name, scenario id, or scorecard key here conflicts with prose in
`PLAN.claude-opus-4-8.md`, `PLAN.gpt-5.5.md`, `AB_TEST_FRAMEWORK.md`, or the
experiment record, **this contract wins for the spike**. The plans remain the
source of truth for *gameplay intent*; this file is the source of truth for
*wire/field names*.

- Scope: read-only spike. No world mutation, no real cluster deploy, no secrets.
- Inputs reconciled: `README.md`, `CONCEPT_BRIEF.md`, `AB_TEST_FRAMEWORK.md`,
  `PI.md`, `PLAN.md`, `PLAN.claude-opus-4-8.md`, `PLAN.gpt-5.5.md`,
  `docs/experiments/2026-06-26-industrial-cognition-ab.md`.

---

## 0. Conventions (read first)

- **Wire format is JSON. JSON field names are `camelCase`.** This applies to
  every fixture (`bridge/fixtures/*.json`), every bridge HTTP response
  (Task 007), and everything the Pi extension consumes (Task 008).
- The **Factorio mod (Lua)** may use `snake_case` internally, but whatever it
  emits for the bridge **must serialize to the `camelCase` contract below**.
  The Lua↔JSON boundary is the only place a rename is allowed.
- **Identifiers** (`experimentId`, `variantId`, `scenarioId`, finding `code`,
  capacity `key`, scorecard `key`) are lowercase `kebab-case` string literals.
  They are stable and case-sensitive. Do not invent new ones in later tasks
  without updating this contract.
- **Enums are closed.** Where a field lists allowed values, only those values
  are valid. Add new values by amending this file, not ad hoc.
- All times are ISO-8601 UTC strings; all `tick` values are integers
  (Factorio game ticks, 60/sec).
- **Both variants MUST be representable by the same schema.** A consumer must
  never need to branch on `variantId` to *parse* a snapshot — only to *label*
  it. Variant differences live entirely inside the generic `cognition.capacities`
  array and the variant metadata block.

### Stable top-level constants

| Constant | Value |
|---|---|
| `experimentId` | `industrial-cognition-ab` |
| Experiment date slug / file stem | `2026-06-26-industrial-cognition-ab` |
| Snapshot schema version | `cogigator.snapshot.v1` |
| Analyze schema version | `cogigator.analyze.v1` |
| Variant A `variantId` | `cognition-flow` |
| Variant B `variantId` | `capacity-vector` |

---

## 1. Variant metadata

Every variant module (Task 004 / Task 005), the bridge (Task 007), and the Pi
extension (Task 008) refer to a variant through this exact object. The mod
variant module exposes it as a **pure-data descriptor**; the bridge echoes it;
Pi only displays it.

```json
{
  "experimentId": "industrial-cognition-ab",
  "variantId": "cognition-flow",
  "variantLetter": "A",
  "variantLabel": "Sightline + Cognition Flow",
  "inspiredBy": "claude-opus-4-8",
  "stationKind": "core",
  "stationLabel": "Cogigator Core",
  "capacityKeys": ["sightline", "cognitionFlow", "cognitionBuffer", "memory"],
  "degradationFlags": ["overloaded"],
  "tagline": "Two scarcities: where it can look, and how hard it can think."
}
```

### Field reference

| Field | Type | Notes |
|---|---|---|
| `experimentId` | string | Always `industrial-cognition-ab`. |
| `variantId` | enum | `cognition-flow` \| `capacity-vector`. |
| `variantLetter` | enum | `A` \| `B`. A = `cognition-flow`, B = `capacity-vector`. |
| `variantLabel` | string | Human display name. |
| `inspiredBy` | enum | `claude-opus-4-8` (A) \| `gpt-5.5` (B). Provenance only. |
| `stationKind` | enum | `core` (A) \| `field-station` (B). The observation entity's role tag. |
| `stationLabel` | string | Player-facing entity name for the observation structure. |
| `capacityKeys` | string[] | Ordered list of capacity dimensions this variant exposes (see §3). Drives generic rendering. |
| `degradationFlags` | string[] | Variant-specific boolean degradation flags surfaced in `cognition.degradation.flags` (see §3.3). |
| `tagline` | string | One-line player-facing summary. |

### The two frozen variant descriptors

**Variant A — `cognition-flow`** (Task 004, inspired by `PLAN.claude-opus-4-8.md`):

| Field | Value |
|---|---|
| `variantId` | `cognition-flow` |
| `variantLetter` | `A` |
| `variantLabel` | `Sightline + Cognition Flow` |
| `inspiredBy` | `claude-opus-4-8` |
| `stationKind` | `core` |
| `stationLabel` | `Cogigator Core` |
| `capacityKeys` | `["sightline", "cognitionFlow", "cognitionBuffer", "memory"]` |
| `degradationFlags` | `["overloaded"]` |

**Variant B — `capacity-vector`** (Task 005, inspired by `PLAN.gpt-5.5.md`):

| Field | Value |
|---|---|
| `variantId` | `capacity-vector` |
| `variantLetter` | `B` |
| `variantLabel` | `Field Station + Capacity Vector` |
| `inspiredBy` | `gpt-5.5` |
| `stationKind` | `field-station` |
| `stationLabel` | `Cogigator Field Station` |
| `capacityKeys` | `["scan", "attention", "memory", "planning"]` |
| `degradationFlags` | `[]` |

> Note: `memory` is intentionally shared by both variants (same key, same
> meaning: retained history / context depth). This is the one capacity overlap
> and is allowed — it makes the variants comparable on at least one axis.

---

## 2. Shared snapshot shape (`cogigator.snapshot.v1`)

The snapshot is **the unit of observation**: one bounded JSON document per
station. It is produced by the mod (Task 006), stored as fixtures (Task 003),
served by the bridge `GET /snapshot` (Task 007), and consumed by Pi (Task 008).

### 2.1 Top-level envelope

```json
{
  "schemaVersion": "cogigator.snapshot.v1",
  "experimentId": "industrial-cognition-ab",
  "scenarioId": "starved-assembler",
  "variant": { "...": "variant metadata object from §1" },
  "requestId": "00000000-0000-0000-0000-000000000000",
  "serverTime": "2026-06-26T00:00:00Z",
  "factorio": { "version": "2.0.x", "save": "spike-fixture" },
  "station": { "...": "see §2.2" },
  "worksite": { "...": "see §2.3" },
  "tick": 123456,
  "cognition": { "...": "see §3" },
  "power": { "...": "see §2.4" },
  "entities": { "...": "see §2.5" },
  "findings": [ "...": "see §4" ],
  "omitted": { "...": "see §2.6" },
  "truncated": false,
  "expectedDiagnosis": [ "...": "fixtures only, see §2.7" ]
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `schemaVersion` | string | yes | Always `cogigator.snapshot.v1`. |
| `experimentId` | string | yes | Always `industrial-cognition-ab`. |
| `scenarioId` | enum | yes | One of §5 scenario ids. |
| `variant` | object | yes | The full §1 metadata object (not just the id). |
| `requestId` | string (uuid) | yes | Fixtures may use a fixed/zero uuid. |
| `serverTime` | ISO-8601 | yes | Fixtures may use a fixed timestamp. |
| `factorio` | object | yes | `{ version, save }`. Fixtures use `version: "2.0.x"`. |
| `station` | object | yes | §2.2. |
| `worksite` | object | yes | §2.3. |
| `tick` | int | yes | Game tick this snapshot represents. |
| `cognition` | object | yes | §3. The variant-distinguishing block. |
| `power` | object | yes | §2.4. |
| `entities` | object | yes | §2.5. |
| `findings` | array | yes | §4. May be empty. |
| `omitted` | object | yes | §2.6. |
| `truncated` | bool | yes | True if any section was capped. |
| `expectedDiagnosis` | array | fixtures only | §2.7. Omit in live mod output. |

### 2.2 `station`

```json
{
  "stationId": "core-1",
  "stationKind": "core",
  "stationLabel": "Cogigator Core",
  "permissionMode": "read-only-advisor",
  "transportHealth": "ok",
  "status": "live"
}
```

| Field | Type | Notes |
|---|---|---|
| `stationId` | string | Stable id of the observation entity. Mirrors `variant.stationKind`. |
| `stationKind` | enum | `core` \| `field-station`. Must equal `variant.stationKind`. |
| `stationLabel` | string | Player-facing name. |
| `permissionMode` | enum | `silent-monitor` \| `read-only-advisor` \| `planner` \| `construction-draftsman` \| `demolition-draftsman` \| `debug-executor`. **Spike fixtures use `read-only-advisor` or `silent-monitor` only.** Mutating tiers exist in the enum but MUST NOT be exercised in the spike. |
| `transportHealth` | enum | `ok` \| `degraded` \| `offline`. |
| `status` | enum | `live` \| `stale` \| `offline` \| `overloaded`. |

### 2.3 `worksite`

Rectangular, in tiles, on a single surface. (Both plans mandate rectangles.)

```json
{
  "surface": "nauvis",
  "bounds": { "left": 0, "top": 0, "right": 32, "bottom": 32 },
  "width": 32,
  "height": 32
}
```

| Field | Type | Notes |
|---|---|---|
| `surface` | string | Surface name. |
| `bounds` | object | `{ left, top, right, bottom }` tile coordinates (numbers). |
| `width` / `height` | int | Derived convenience; `right-left` / `bottom-top`. |

### 2.4 `power`

```json
{ "satisfaction": 0.42, "demandKw": 1200, "supplyKw": 504, "state": "low" }
```

| Field | Type | Notes |
|---|---|---|
| `satisfaction` | float 0..1 | Fraction of demand met. |
| `demandKw` / `supplyKw` | number | kW. Optional but recommended. |
| `state` | enum | `ok` \| `low` \| `none`. |

### 2.5 `entities`

A **bounded summary**, never a raw dump. Counts plus a capped list of
representative machines.

```json
{
  "totalCount": 87,
  "byType": { "assembling-machine": 12, "transport-belt": 40, "inserter": 18 },
  "representative": [
    {
      "unitNumber": 101,
      "name": "assembling-machine-2",
      "type": "assembling-machine",
      "recipe": "iron-gear-wheel",
      "status": "item-ingredient-shortage",
      "position": { "x": 4, "y": 6 },
      "inputs": [{ "item": "iron-plate", "count": 0 }],
      "outputs": [{ "item": "iron-gear-wheel", "count": 50 }],
      "fluids": [],
      "powerState": "working"
    }
  ]
}
```

| Field | Type | Notes |
|---|---|---|
| `totalCount` | int | Total entities in worksite (pre-cap). |
| `byType` | object | Map of Factorio `type` → count. |
| `representative` | array | Capped sample of notable machines. Each item: `unitNumber`, `name`, `type`, optional `recipe`, `status`, `position {x,y}`, optional `inputs`/`outputs`/`fluids` (arrays of `{item|fluid, count|amount}`), `powerState`. |

`status` strings on representative machines may use Factorio-native status
labels (e.g. `working`, `item-ingredient-shortage`, `full-output`,
`no-power`, `fluid-ingredient-shortage`); diagnostics in `findings` (§4) are
the normalized, cross-variant layer.

### 2.6 `omitted`

Honest truncation marker. Dense scenarios (`dense-cell-truncated`) populate
this; others set zeros.

```json
{ "entityCount": 55, "reason": "entity-cap", "caps": { "representative": 8, "byType": 64 } }
```

| Field | Type | Notes |
|---|---|---|
| `entityCount` | int | How many entities were dropped from `representative`. |
| `reason` | enum | `none` \| `entity-cap` \| `cognition-budget` \| `byte-cap`. |
| `caps` | object | The numeric caps applied (free-form ints). |

When `omitted.reason !== "none"`, the envelope `truncated` MUST be `true`.

### 2.7 `expectedDiagnosis` (fixtures only)

Fixtures (Task 003) carry the ground-truth answer so the bridge `/analyze`
(Task 007) and human scorers (Task 010) can check correctness. **The live mod
must NOT emit this field.**

```json
[
  {
    "findingCode": "input-starved",
    "summary": "Gear assembler starved: no iron-plate on input.",
    "primary": true
  }
]
```

| Field | Type | Notes |
|---|---|---|
| `findingCode` | enum | A §4 finding code expected to appear. |
| `summary` | string | Human-readable expected diagnosis. |
| `primary` | bool | True for the single headline cause. |

---

## 3. Cognition block (`cognition`) — the variant-distinguishing layer

This is the **only** part of the snapshot whose *contents* differ by variant,
and it does so through a **generic, variant-agnostic structure**. Task 006's
common report code iterates `capacities` without knowing which variant produced
them. Variant modules (Task 004/005) own only the *values* and the *capacity
keys*, never the structure.

```json
{
  "model": "cognition-flow",
  "capacities": [ "...": "see §3.1" ],
  "degradation": { "...": "see §3.3" }
}
```

| Field | Type | Notes |
|---|---|---|
| `model` | enum | Equals `variantId`: `cognition-flow` \| `capacity-vector`. |
| `capacities` | array | One entry per `variant.capacityKeys`, in that order. §3.1. |
| `degradation` | object | Normalized degradation state. §3.3. |

### 3.1 Capacity entry

```json
{
  "key": "cognitionFlow",
  "label": "Cognition Flow",
  "value": 8.0,
  "limit": 20.0,
  "unit": "cog/min",
  "satisfied": false,
  "bottleneck": true,
  "note": "Datacenter under-built; flow below analysis demand."
}
```

| Field | Type | Notes |
|---|---|---|
| `key` | enum | A capacity key from §3.2. Must be one of `variant.capacityKeys`. |
| `label` | string | Player-facing label. |
| `value` | number | Current available/produced amount. |
| `limit` | number | Demand or max for this dimension (denominator for "satisfied"). |
| `unit` | string | Free-form unit hint (`cog/min`, `units`, `slots`, `tiles²`, `bool`). |
| `satisfied` | bool | `value` meets `limit`. |
| `bottleneck` | bool | This capacity is the binding constraint. |
| `note` | string | Optional one-line build hint ("build more X"). |

For boolean capacities (e.g. Variant B `planning`: on/off), use `unit: "bool"`,
`value`/`limit` ∈ {0,1}.

### 3.2 Frozen capacity keys per variant

**Variant A (`cognition-flow`)** — exactly these four keys, in order:

| `key` | Meaning (from Claude plan) | Typical `unit` |
|---|---|---|
| `sightline` | Where it can look — observation reach / zone coverage. | `tiles²` |
| `cognitionFlow` | Manufactured think-rate (throughput). | `cog/min` |
| `cognitionBuffer` | Stored cognition for deep/burst requests (Memory Banks). | `cog` |
| `memory` | Retained history / context depth. | `units` |

Variant A degradation flag: `overloaded` (buffer empty + low flow → queued or
deterministic-only answers).

**Variant B (`capacity-vector`)** — exactly these four keys, in order:

| `key` | Meaning (from GPT plan) | Typical `unit` |
|---|---|---|
| `scan` | Area/entity density sampled per interval. | `tiles²` |
| `attention` | How many stations/watches can be active. | `slots` |
| `memory` | Retained history. | `units` |
| `planning` | Whether build-intent reasoning is enabled (gate). | `bool` |

Variant B exposes no extra degradation flags; degradation is read directly from
unsatisfied capacities.

### 3.3 `degradation`

Normalized so the common report and Pi can render degradation identically
regardless of variant.

```json
{
  "degraded": true,
  "level": "partial",
  "flags": { "overloaded": false },
  "reasons": ["cognition-flow-below-demand"],
  "effects": ["report-cadence-slowed", "analysis-depth-reduced"]
}
```

| Field | Type | Notes |
|---|---|---|
| `degraded` | bool | Any capacity unsatisfied OR any flag set. |
| `level` | enum | `none` \| `partial` \| `severe`. |
| `flags` | object | Variant-specific booleans declared in `variant.degradationFlags` (Variant A: `overloaded`; Variant B: `{}`). |
| `reasons` | string[] | Machine-readable reason codes (free-form kebab-case). |
| `effects` | string[] | Player-facing consequences. Suggested closed set: `report-cadence-slowed`, `analysis-depth-reduced`, `watches-disabled`, `worksite-shrunk`, `answers-queued`, `deterministic-only`, `planning-disabled`. |

---

## 4. Findings vocabulary (shared, identical across variants)

`findings` is an array of normalized diagnostics computed deterministically by
the mod (Task 006) — never invented by an LLM. **Both variants MUST use this
identical vocabulary** (Task 006 acceptance criterion). The variant only
changes the cognition explanation, never the finding codes.

### 4.1 Finding object

```json
{
  "code": "input-starved",
  "severity": "error",
  "subjectUnitNumber": 101,
  "subjectName": "assembling-machine-2",
  "message": "Assembler starved: input iron-plate empty.",
  "evidence": { "item": "iron-plate", "count": 0 },
  "tick": 123456
}
```

| Field | Type | Notes |
|---|---|---|
| `code` | enum | One of §4.2. |
| `severity` | enum | `info` \| `warning` \| `error`. |
| `subjectUnitNumber` | int \| null | Entity the finding is about, if any. |
| `subjectName` | string \| null | Prototype name of the subject. |
| `message` | string | One-line human-readable diagnosis. |
| `evidence` | object | Free-form numeric/string evidence backing the finding. |
| `tick` | int | The snapshot tick (citation anchor). |

### 4.2 Finding codes (closed enum)

| `code` | Meaning |
|---|---|
| `input-starved` | Machine missing a solid input / belt empty into it. |
| `output-blocked` | Product cannot leave (output full / belt backed up). |
| `no-recipe` | Machine has no recipe set. |
| `missing-fluid` | Required fluid input empty/absent. |
| `no-power` | Entity unpowered. |
| `low-power` | Electric network under-supplied (satisfaction < 1). |
| `overheating` | Thermal/coolant limit (compute machine waste heat). |
| `inserter-blocked` | Inserter source or target blocked. |
| `belt-starved` | Belt segment empty where flow expected. |
| `belt-backed-up` | Belt segment saturated/jammed. |
| `ghost-missing-material` | Construction ghost lacks required item. |
| `patch-below-threshold` | Resource patch below a low-ore threshold. |
| `under-computed` | Station degraded by insufficient cognition/capacity. |

> Citation rule (both plans, non-negotiable): any assistant answer must cite
> `station.stationId`, `tick`, and the `findings[].code` it relied on. Pi
> (Task 008) and `/analyze` (Task 007) surface these three together.

---

## 5. Scenario IDs (the shared test corpus)

Six deterministic fixture scenarios. Task 003 creates one `bridge/fixtures/
<scenarioId>.json` per id; the bridge serves them by `scenarioId` × `variantId`
(Task 007); Task 010 scores against them. **Use these exact ids** — they are the
filename stems and the `scenarioId` enum values.

| `scenarioId` | What it sets up | Expected primary finding(s) |
|---|---|---|
| `starved-assembler` | Assembler input missing / feed belt empty. | `input-starved` |
| `blocked-output` | Product cannot leave a machine. | `output-blocked` (often + `belt-backed-up`) |
| `missing-fluid` | Machine waits on a fluid input. | `missing-fluid` |
| `low-power` | Electric network under-supplied. | `low-power` (or `no-power`) |
| `under-computed` | Observation exists but cognition/capacity is degraded. | `under-computed` |
| `dense-cell-truncated` | Many entities; report must truncate honestly. | any real findings + `truncated:true`, `omitted.reason:"entity-cap"` |

### Scenario 7 — comprehension probe (NOT a fixture)

`AB_TEST_FRAMEWORK.md` lists a seventh scenario, *"Player confusion probe — can
a human explain what to build next after reading the UI?"* This is a **manual
human probe**, not a JSON fixture. It has **no `scenarioId` and no fixture
file**; it is exercised only during the demo run and scored via the scorecard
(`player-comprehension`, `degradation-clarity`). Later tasks must not expect a
`dense-cell`/`probe` fixture for it.

### Fixture requirements (Task 003)

Each fixture is a full §2 snapshot envelope and additionally MUST:

- be valid for **both** variants (same file structure; only `variant`,
  `cognition`, and cognition-driven `findings`/`degradation` differ — Task 003
  may emit one file per `scenarioId`×`variantId`, or one parameterized base —
  bridge contract only requires it can serve both);
- set `experimentId`, `scenarioId`, full `variant` block, `station`,
  `worksite`, `tick`, `cognition` (capacities + degradation), `findings`,
  `omitted`, `truncated`;
- include `expectedDiagnosis` (§2.7) for scoring;
- contain **no secrets, IPs, credentials, or real cluster output**.

---

## 6. Bridge API surface (spike subset)

Task 007 implements exactly these endpoints (a read-only subset of the full
`PI.md` contract). All responses are JSON, `camelCase`, and carry
`schemaVersion`, `requestId`, `serverTime`.

| Method & path | Returns |
|---|---|
| `GET /health` | `{ schemaVersion, status: "ok", serverTime }` |
| `GET /version` | `{ schemaVersion, bridgeVersion, snapshotSchema: "cogigator.snapshot.v1" }` |
| `GET /experiments/current` | The current experiment + both variant metadata blocks (§1) + scenario id list (§5). |
| `GET /scenarios` | Array of `{ scenarioId, title, expectedPrimary }`. |
| `GET /snapshot?scenarioId=<id>&variantId=<id>` | One §2 snapshot. 400 on unknown id; the two params are required. |
| `POST /analyze` | Deterministic cited findings (§6.1). **No LLM output.** |

The API is **variant-agnostic**: it serves the same schema and same endpoints
for both variants; variant differences appear only inside the payload.

### 6.1 `/analyze` response (`cogigator.analyze.v1`)

```json
{
  "schemaVersion": "cogigator.analyze.v1",
  "requestId": "uuid",
  "serverTime": "2026-06-26T00:00:00Z",
  "scenarioId": "starved-assembler",
  "variantId": "cognition-flow",
  "citations": { "stationId": "core-1", "tick": 123456 },
  "findings": [ "...": "§4 finding objects, deterministically derived" ],
  "primaryFindingCode": "input-starved",
  "cognitionExplanation": "Flow below demand; answers run deterministic-only.",
  "truncated": false
}
```

`POST /analyze` request body: `{ "scenarioId": "...", "variantId": "...",
"question": "..." }`. The `question` is echoed/contextualized but the findings
are derived from the fixture, not generated.

---

## 7. Pi extension display contract (Task 008)

The Pi extension is **variant-agnostic**: it displays metadata, never encodes
variant policy. From a snapshot/analyze response it surfaces exactly:

`experimentId`, `variant.variantId` (+ `variantLabel`), `scenarioId`,
`station.stationId` (+ `stationKind`), `tick`, `findings[]` (code + message),
and `cognition.degradation` (`degraded`, `level`, `effects`).

Tools/commands (read-only only): `cogigator_status`, `cogigator_snapshot`,
`cogigator_analyze`, `/cogigator-connect`, `/cogigator-status`,
`/cogigator-snapshot`, `/cogigator-experiment`. **No tool may mutate game
state.** Footer status: `cogigator: disconnected|connected|degraded`.

---

## 8. Scorecard fields (Task 010)

Task 010 builds `…-industrial-cognition-ab.scorecard.md`. The scorecard scores
**each variant per scenario** on the metrics below. Keys are stable.

### 8.1 Weighted decision metrics (primary)

Score 1–5 (5 = best) unless noted. Weights sum to 100.

| `key` | Label | Type | Weight | Direction |
|---|---|---|---:|---|
| `player-comprehension` | Player can explain what to build next | qualitative | 20 | higher better |
| `factorio-native-feel` | Feels like logistics/infra, not a menu | qualitative | 18 | higher better |
| `diagnostic-usefulness` | Diagnosis matches the scenario's real cause | qualitative+count | 20 | higher better |
| `degradation-clarity` | Player understands why capability is degraded | qualitative | 14 | higher better |
| `fun-inspiration` | Memorable / exciting / "I want to build this" | qualitative | 12 | higher better |
| `implementation-friction` | How many special cases the variant needed | qualitative | 8 | higher = less friction |
| `future-extensibility` | Scales to watches/planner/multi-fluid later | qualitative | 8 | higher better |

`Total = Σ(score × weight) / 100`, per variant, averaged across scenarios.

### 8.2 Supporting observational metrics (recorded, not weighted)

| `key` | Label | Type |
|---|---|---|
| `time-to-first-useful-answer` | Setup → grounded diagnosis | quantitative |
| `report-correctness` | Diagnosis vs. `expectedDiagnosis` | count (n correct / n scenarios) |
| `ups-scan-cost` | Tick-budget / timing observation | quantitative (note: spike uses fixtures, may be N/A) |
| `documentation-clarity` | Could the timeline explain it compactly | qualitative |

### 8.3 Decision field

| `key` | Allowed values |
|---|---|
| `merge-potential` | `merge` \| `iterate` \| `park` \| `discard` |

The final experiment decision (`…-industrial-cognition-ab.md`) records one of:
`merge`, `synthesize`, `iterate`, `park`.

---

## 9. Cross-task field map (quick reference)

| Concept | Frozen name(s) | Defined in | Consumed by |
|---|---|---|---|
| Experiment id | `industrial-cognition-ab` | §0 | 003, 007, 008, 010 |
| Variant ids | `cognition-flow`, `capacity-vector` | §1 | 004, 005, 007, 008 |
| Variant A capacities | `sightline`, `cognitionFlow`, `cognitionBuffer`, `memory` | §3.2 | 004, 006 |
| Variant B capacities | `scan`, `attention`, `memory`, `planning` | §3.2 | 005, 006 |
| Variant A degradation flag | `overloaded` | §3.3 | 004, 006, 008 |
| Snapshot schema | `cogigator.snapshot.v1` | §2 | 003, 006, 007, 008 |
| Findings enum | §4.2 codes | §4 | 003, 006, 007 |
| Scenario ids | §5 (6 ids) | §5 | 003, 007, 009, 010 |
| Bridge endpoints | §6 | §6 | 007, 008, 009 |
| Analyze schema | `cogigator.analyze.v1` | §6.1 | 007, 008 |
| Scorecard keys | §8 | §8 | 010, 013 |

---

## 10. Invariants every downstream task must hold

1. **No world mutation path.** Mutating permission tiers exist in the enum but
   are never exercised; no fixture, bridge route, or Pi tool mutates state.
2. **Variant-agnostic substrate.** Common mod report code, the bridge, and the
   Pi extension must parse a snapshot without branching on `variantId`. Only the
   `cognition.capacities` values and the `variant` metadata differ.
3. **Identical finding vocabulary.** Both variants emit the same §4.2 codes.
4. **Honest truncation.** `truncated` and `omitted.reason` stay consistent.
5. **Citations always available.** `stationId` + `tick` + `findings[].code`.
6. **Public-safe.** No secrets, credentials, private IPs, RCON passwords, or raw
   cluster output in any fixture, doc, code sample, or response.
7. **This contract is the tiebreaker** for field/identifier names in the spike.
