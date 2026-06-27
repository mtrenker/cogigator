# Scorecard: Industrial Cognition A/B (`2026-06-26-industrial-cognition-ab`)

- Date: 2026-06-26
- Status: local integration check complete; subjective human scoring still pending
- Related documents:
  - [Implementation contract](2026-06-26-industrial-cognition-ab.contract.md) — §8 defines these scorecard fields
  - [Experiment record](2026-06-26-industrial-cognition-ab.md) — context, variants, decision output
  - [Demo runbook](2026-06-26-industrial-cognition-ab.runbook.md) — step-by-step local A/B loop

## How to Use This Scorecard

1. Run the local demo using the [runbook](2026-06-26-industrial-cognition-ab.runbook.md):
   start the bridge, fetch each scenario for both variants, call `/analyze`, and optionally load Pi tools.
2. After observing each scenario for both variants, fill in the score cells in the **Per-Scenario Worksheets** below (one row per scenario, one column per variant, score 1–5).
3. For Scenario 7 (comprehension probe), have a second person read a filled-in snapshot or analyze response and answer the prompt question without assistance.
4. When all scenarios are scored, copy scores into the **Weighted Summary Table** and calculate per-variant totals.
5. Record supporting observational metrics (time-to-answer, report correctness, etc.) in the **Supporting Metrics** section.
6. Fill in the **Decision** field at the bottom and copy the winner + decision back to the [experiment record](2026-06-26-industrial-cognition-ab.md).

> **Acceptance criterion:** this document is complete when every blank cell in §§1–7 worksheet tables is filled, the weighted totals are computed, and the `merge-potential` field holds one of `merge | iterate | park | discard`.

---

## Metric Reference

### Weighted Decision Metrics (score 1–5, weights sum to 100)

| Key | Label | Weight | Direction |
|---|---|---:|---|
| `player-comprehension` | Player can explain what to build next | 20 | higher = better |
| `factorio-native-feel` | Feels like logistics/infra, not a menu | 18 | higher = better |
| `diagnostic-usefulness` | Diagnosis matches the scenario's real cause | 20 | higher = better |
| `degradation-clarity` | Player understands why capability is degraded | 14 | higher = better |
| `fun-inspiration` | Memorable / exciting / "I want to build this" | 12 | higher = better |
| `implementation-friction` | How many special cases the variant needed | 8 | higher = less friction |
| `future-extensibility` | Scales to watches/planner/multi-fluid later | 8 | higher = better |

**Weighted total formula:**

```
Σ(score × weight) / 100
```

Per variant, computed from scenario-average scores.

### Supporting Observational Metrics (recorded, not weighted)

| Key | Label | Type |
|---|---|---|
| `time-to-first-useful-answer` | Setup → grounded diagnosis | quantitative |
| `report-correctness` | Diagnosis vs. `expectedDiagnosis` | count (n correct / 6 scenarios) |
| `ups-scan-cost` | Tick-budget observation | quantitative (N/A for fixture-based spike) |
| `documentation-clarity` | Could a timeline entry explain it compactly | qualitative |

---

## Scoring Rubrics

Use these rubrics to assign consistent 1–5 scores across both variants.

### `player-comprehension` — Player can explain what to build next

After reviewing the snapshot/analyze output:

| Score | Meaning |
|---|---|
| 5 | Observer immediately names the bottleneck and the exact machine or resource to address it |
| 4 | Observer names the right bottleneck but is slightly uncertain about the specific fix |
| 3 | Observer identifies the general problem area but cannot articulate the next build step |
| 2 | Observer can read the numbers but cannot connect them to factory action |
| 1 | Observer is confused; output does not point toward any actionable conclusion |

*Primary reference scenarios: `starved-assembler`, `blocked-output`, `missing-fluid`, `low-power`. Also directly tested by Scenario 7 (comprehension probe).*

### `factorio-native-feel` — Feels like logistics/infra, not a menu

| Score | Meaning |
|---|---|
| 5 | Variant reads like a physical system you built: the factory produced/limited cognition |
| 4 | Strong factory metaphor; one abstraction feels slightly forced |
| 3 | Mixed: some elements feel Factorio-native, others feel like a config screen |
| 2 | Mostly feels like a settings panel or status dashboard, not a manufactured resource |
| 1 | Feels entirely detached from Factorio gameplay and manufacturing |

### `diagnostic-usefulness` — Diagnosis matches the scenario's real cause

*Compare `findings[].code` and `primaryFindingCode` from `/analyze` against `expectedDiagnosis` in the fixture.*

| Score | Meaning |
|---|---|
| 5 | Primary finding matches `expectedDiagnosis[primary=true]`; supporting findings are relevant; citation present |
| 4 | Primary matches; one minor supporting finding is irrelevant or missing |
| 3 | Primary finding is correct but message is vague or citation is incomplete |
| 2 | Diagnosis is partially correct but the primary cause is buried or obscured |
| 1 | Primary finding does not match expected diagnosis, or no findings returned |

*For `dense-cell-truncated`: also verify `truncated: true`, `omitted.reason: "entity-cap"` present in snapshot.*

### `degradation-clarity` — Player understands why capability is degraded

*Primary reference scenario: `under-computed`. Also applicable to `dense-cell-truncated`.*

| Score | Meaning |
|---|---|
| 5 | `cognition.degradation` block clearly tells the player what is degraded, why, and what the consequence is (`effects[]`) |
| 4 | Degradation is clear, but effects are listed without sufficient player-facing explanation |
| 3 | Player can see something is wrong but cannot immediately determine what to build to fix it |
| 2 | Degradation flags exist but lack player-readable context |
| 1 | No degradation signal visible, or signal is contradictory |

*Non-degraded scenarios (e.g. `starved-assembler` at full cognition) should score 5 trivially — the station is not degraded.*

### `fun-inspiration` — Memorable / exciting / "I want to build this"

| Score | Meaning |
|---|---|
| 5 | After seeing this variant, the evaluator wants to keep playing and build toward it |
| 4 | Positive reaction; the mechanic is interesting but not especially striking |
| 3 | Neutral; the variant is competent but unremarkable |
| 2 | The variant feels tedious or overly complex without payoff |
| 1 | The variant actively detracts from the experience |

### `implementation-friction` — How many special cases the variant needed

*Higher score = less friction.*

| Score | Meaning |
|---|---|
| 5 | All six scenarios work through the generic substrate with no variant-specific branches |
| 4 | One minor variant-specific tweak needed (e.g. a labelling difference) |
| 3 | Two to three scenarios required variant-specific logic or extra report fields |
| 2 | Several scenarios needed special handling; substrate coverage was partial |
| 1 | Most scenarios required deep variant-specific plumbing; substrate was bypassed |

*Assess this by reviewing how cleanly the `cognition.capacities` array drove the report for each scenario.*

### `future-extensibility` — Scales to watches/planner/multi-fluid later

| Score | Meaning |
|---|---|
| 5 | The capacity model clearly accommodates watches, planner, and multi-fluid circuits without structural changes |
| 4 | Core structure is extensible; one capacity dimension would need renaming or splitting |
| 3 | Extension is possible but would require adding variant-specific keys to the contract |
| 2 | Extension would require breaking changes to the snapshot schema |
| 1 | Capacity model is a dead end; watches/planner could not be expressed in this structure |

---

## Per-Scenario Worksheets

Instructions:
- Run each scenario for both variants using `/snapshot?scenarioId=<id>&variantId=<id>` and `/analyze`.
- Score 1–5 per metric per variant. Leave N/A only when a metric genuinely cannot be observed (e.g. `degradation-clarity` for a fully-healthy non-degraded scenario).
- Add brief notes in the Notes column.

> Metric abbreviations used in tables:
> **PC** = player-comprehension (×20) | **FN** = factorio-native-feel (×18) | **DU** = diagnostic-usefulness (×20) | **DC** = degradation-clarity (×14) | **FI** = fun-inspiration (×12) | **IF** = implementation-friction (×8) | **FE** = future-extensibility (×8)

---

### Scenario 1: `starved-assembler`

Expected primary finding: `input-starved`

Bridge commands:
```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=starved-assembler&variantId=cognition-flow" | jq
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=starved-assembler&variantId=capacity-vector" | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"starved-assembler","variantId":"cognition-flow","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"starved-assembler","variantId":"capacity-vector","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
```

| Metric | Weight | Variant A (`cognition-flow`) | Variant B (`capacity-vector`) | Notes |
|---|---:|---|---|---|
| `player-comprehension` (PC) | 20 | ___ | ___ | |
| `factorio-native-feel` (FN) | 18 | ___ | ___ | |
| `diagnostic-usefulness` (DU) | 20 | ___ | ___ | Check: `primaryFindingCode = input-starved`? |
| `degradation-clarity` (DC) | 14 | N/A | N/A | Station not degraded in this scenario |
| `fun-inspiration` (FI) | 12 | ___ | ___ | |
| `implementation-friction` (IF) | 8 | ___ | ___ | |
| `future-extensibility` (FE) | 8 | ___ | ___ | |

Observations:

> _Record what you saw in each variant's output here._

---

### Scenario 2: `blocked-output`

Expected primary findings: `output-blocked` (often + `belt-backed-up`)

Bridge commands:
```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=blocked-output&variantId=cognition-flow" | jq
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=blocked-output&variantId=capacity-vector" | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"blocked-output","variantId":"cognition-flow","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"blocked-output","variantId":"capacity-vector","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
```

| Metric | Weight | Variant A (`cognition-flow`) | Variant B (`capacity-vector`) | Notes |
|---|---:|---|---|---|
| `player-comprehension` (PC) | 20 | ___ | ___ | |
| `factorio-native-feel` (FN) | 18 | ___ | ___ | |
| `diagnostic-usefulness` (DU) | 20 | ___ | ___ | Check: `primaryFindingCode = output-blocked`? |
| `degradation-clarity` (DC) | 14 | N/A | N/A | Station not degraded in this scenario |
| `fun-inspiration` (FI) | 12 | ___ | ___ | |
| `implementation-friction` (IF) | 8 | ___ | ___ | |
| `future-extensibility` (FE) | 8 | ___ | ___ | |

Observations:

> _Record what you saw in each variant's output here._

---

### Scenario 3: `missing-fluid`

Expected primary finding: `missing-fluid`

Bridge commands:
```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=missing-fluid&variantId=cognition-flow" | jq
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=missing-fluid&variantId=capacity-vector" | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"missing-fluid","variantId":"cognition-flow","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"missing-fluid","variantId":"capacity-vector","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
```

| Metric | Weight | Variant A (`cognition-flow`) | Variant B (`capacity-vector`) | Notes |
|---|---:|---|---|---|
| `player-comprehension` (PC) | 20 | ___ | ___ | |
| `factorio-native-feel` (FN) | 18 | ___ | ___ | |
| `diagnostic-usefulness` (DU) | 20 | ___ | ___ | Check: `primaryFindingCode = missing-fluid`? |
| `degradation-clarity` (DC) | 14 | N/A | N/A | Station not degraded in this scenario |
| `fun-inspiration` (FI) | 12 | ___ | ___ | |
| `implementation-friction` (IF) | 8 | ___ | ___ | |
| `future-extensibility` (FE) | 8 | ___ | ___ | |

Observations:

> _Record what you saw in each variant's output here._

---

### Scenario 4: `low-power`

Expected primary findings: `low-power` (or `no-power`)

Bridge commands:
```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=low-power&variantId=cognition-flow" | jq
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=low-power&variantId=capacity-vector" | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"low-power","variantId":"cognition-flow","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"low-power","variantId":"capacity-vector","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
```

| Metric | Weight | Variant A (`cognition-flow`) | Variant B (`capacity-vector`) | Notes |
|---|---:|---|---|---|
| `player-comprehension` (PC) | 20 | ___ | ___ | |
| `factorio-native-feel` (FN) | 18 | ___ | ___ | |
| `diagnostic-usefulness` (DU) | 20 | ___ | ___ | Check: `primaryFindingCode = low-power`? |
| `degradation-clarity` (DC) | 14 | ___ | ___ | Check: `power.state = low`; verify `cognition.degradation` message |
| `fun-inspiration` (FI) | 12 | ___ | ___ | |
| `implementation-friction` (IF) | 8 | ___ | ___ | |
| `future-extensibility` (FE) | 8 | ___ | ___ | |

Observations:

> _Record what you saw in each variant's output here._

---

### Scenario 5: `under-computed`

Expected primary finding: `under-computed`

This is the **primary test of `degradation-clarity`**: the Cogigator station itself is degraded by insufficient cognition/capacity resources.

Bridge commands:
```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=under-computed&variantId=cognition-flow" | jq
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=under-computed&variantId=capacity-vector" | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"under-computed","variantId":"cognition-flow","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"under-computed","variantId":"capacity-vector","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
```

Key things to check in the snapshot:
- Variant A: one or more of `sightline`, `cognitionFlow`, `cognitionBuffer`, `memory` has `satisfied: false` and `bottleneck: true`.
  The `degradation.flags.overloaded` may be `true`.
- Variant B: one or more of `scan`, `attention`, `memory`, `planning` has `satisfied: false`.
  `degradation.degraded: true`, `degradation.level` ∈ `{partial, severe}`.

| Metric | Weight | Variant A (`cognition-flow`) | Variant B (`capacity-vector`) | Notes |
|---|---:|---|---|---|
| `player-comprehension` (PC) | 20 | ___ | ___ | |
| `factorio-native-feel` (FN) | 18 | ___ | ___ | |
| `diagnostic-usefulness` (DU) | 20 | ___ | ___ | Check: `primaryFindingCode = under-computed`? |
| `degradation-clarity` (DC) | 14 | ___ | ___ | **Primary test**: does the player know what to build? |
| `fun-inspiration` (FI) | 12 | ___ | ___ | |
| `implementation-friction` (IF) | 8 | ___ | ___ | |
| `future-extensibility` (FE) | 8 | ___ | ___ | |

Observations:

> _Record what you saw in each variant's output here. Note which capacity was the bottleneck and whether the `effects[]` field gave actionable guidance._

---

### Scenario 6: `dense-cell-truncated`

Expected findings: any real findings + `truncated: true` + `omitted.reason: "entity-cap"`

This scenario tests honest truncation. The snapshot must declare what it dropped.

Bridge commands:
```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=dense-cell-truncated&variantId=cognition-flow" | jq
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=dense-cell-truncated&variantId=capacity-vector" | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"dense-cell-truncated","variantId":"cognition-flow","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
curl -sS -H 'content-type: application/json' \
  -d '{"scenarioId":"dense-cell-truncated","variantId":"capacity-vector","question":"What is wrong?"}' \
  http://127.0.0.1:8787/analyze | jq
```

Truncation checks:
- `truncated: true` in snapshot ✓ / ✗
- `omitted.reason: "entity-cap"` ✓ / ✗
- `omitted.entityCount > 0` ✓ / ✗
- Findings still present despite truncation ✓ / ✗

| Metric | Weight | Variant A (`cognition-flow`) | Variant B (`capacity-vector`) | Notes |
|---|---:|---|---|---|
| `player-comprehension` (PC) | 20 | ___ | ___ | |
| `factorio-native-feel` (FN) | 18 | ___ | ___ | |
| `diagnostic-usefulness` (DU) | 20 | ___ | ___ | Findings present despite truncation? |
| `degradation-clarity` (DC) | 14 | ___ | ___ | Truncation message readable? |
| `fun-inspiration` (FI) | 12 | ___ | ___ | |
| `implementation-friction` (IF) | 8 | ___ | ___ | |
| `future-extensibility` (FE) | 8 | ___ | ___ | |

Observations:

> _Record what you saw. Did truncation affect diagnosis quality? Were both variants equally clear about what was omitted?_

---

### Scenario 7: Comprehension Probe (manual — no fixture)

This is **not a JSON fixture**. It is a human evaluation step per `AB_TEST_FRAMEWORK.md`.

**Procedure:**
1. Complete the demo for any fixture scenario (recommended: `under-computed` or `dense-cell-truncated`).
2. Ask a second person (or return after 10 minutes) to read only the `/analyze` response output for one variant.
3. Ask: *"Based on what you just read, what would you build or change next in the factory?"*
4. Score by whether the answer is correct and specific, without any additional context.

| Metric | Weight | Variant A (`cognition-flow`) | Variant B (`capacity-vector`) | Notes |
|---|---:|---|---|---|
| `player-comprehension` (PC) | 20 | ___ | ___ | **Primary test here**; was the next action clear? |
| `factorio-native-feel` (FN) | 18 | ___ | ___ | Did the response feel like a factory problem? |
| `diagnostic-usefulness` (DU) | 20 | ___ | ___ | Was the diagnosis self-contained enough to act on? |
| `degradation-clarity` (DC) | 14 | ___ | ___ | If degraded: was reason self-explanatory? |
| `fun-inspiration` (FI) | 12 | ___ | ___ | Did the probe reader want to keep playing? |
| `implementation-friction` (IF) | 8 | N/A | N/A | Not applicable (manual probe, not implementation) |
| `future-extensibility` (FE) | 8 | N/A | N/A | Not applicable (manual probe) |

Probe answer (Variant A):

> _Paste or summarize what the test reader said._

Probe answer (Variant B):

> _Paste or summarize what the test reader said._

---

## Weighted Summary Table

After filling all scenario worksheets, average each metric across the six fixture scenarios (omit N/A cells from the average). Scenario 7 scores for `player-comprehension`, `factorio-native-feel`, `diagnostic-usefulness`, `degradation-clarity`, and `fun-inspiration` may be averaged in or recorded separately.

### Step 1 — Per-metric averages across scenarios

| Metric | Weight | Variant A avg | Variant B avg |
|---|---:|---|---|
| `player-comprehension` | 20 | ___ | ___ |
| `factorio-native-feel` | 18 | ___ | ___ |
| `diagnostic-usefulness` | 20 | ___ | ___ |
| `degradation-clarity` | 14 | ___ | ___ |
| `fun-inspiration` | 12 | ___ | ___ |
| `implementation-friction` | 8 | ___ | ___ |
| `future-extensibility` | 8 | ___ | ___ |

### Step 2 — Weighted totals

```
Variant A total = Σ(avg × weight) / 100 = ___
Variant B total = Σ(avg × weight) / 100 = ___
```

Worked formula example (fill in your averages):

| Metric | Weight | A | A×W | B | B×W |
|---|---:|---|---:|---|---:|
| `player-comprehension` | 20 | ___ | ___ | ___ | ___ |
| `factorio-native-feel` | 18 | ___ | ___ | ___ | ___ |
| `diagnostic-usefulness` | 20 | ___ | ___ | ___ | ___ |
| `degradation-clarity` | 14 | ___ | ___ | ___ | ___ |
| `fun-inspiration` | 12 | ___ | ___ | ___ | ___ |
| `implementation-friction` | 8 | ___ | ___ | ___ | ___ |
| `future-extensibility` | 8 | ___ | ___ | ___ | ___ |
| **TOTAL** | **100** | | **___** | | **___** |

Divide column totals by 100 to get the weighted score (max 5.00).

---

## Supporting Observational Metrics

These are recorded but not included in the weighted total.

| Metric | Variant A | Variant B | Notes |
|---|---|---|---|
| `time-to-first-useful-answer` (min) | Local smoke only | Local smoke only | Task 013 verified bridge responses but did not run a timed human demo |
| `report-correctness` (n/6) | 6/6 | 6/6 | All fixture-backed primary diagnoses matched expectations; dense-cell truncation declared honestly |
| `ups-scan-cost` | N/A | N/A | Spike uses fixtures; not measurable without live mod |
| `documentation-clarity` | Pass | Pass | Public docs link contract, runbook, scorecard, and safety review |

### Report Correctness Detail

| Scenario | Expected primary finding | Variant A match | Variant B match |
|---|---|---|---|
| `starved-assembler` | `input-starved` | ✓ | ✓ |
| `blocked-output` | `output-blocked` | ✓ | ✓ |
| `missing-fluid` | `missing-fluid` | ✓ | ✓ |
| `low-power` | `low-power` | ✓ | ✓ |
| `under-computed` | `under-computed` | ✓ | ✓ |
| `dense-cell-truncated` | any + `truncated:true` | ✓ | ✓ |

---

## Decision

Fill in after computing weighted totals and reviewing observations.

| Field | Value |
|---|---|
| Preferred variant | synthesize |
| `merge-potential` | iterate |
| Rationale | Both variants are selectable through the same bridge/Pi contract and both achieved 6/6 fixture report correctness. Because the human comprehension/fun metrics were not run, do not declare a numeric winner; synthesize the clearer capacity-vector diagnostics with the stronger cognition-flow fiction. |
| Next steps | Keep the read-only shared substrate, draft a synthesis proposal, then run the manual comprehension probe before any live Factorio/Kubernetes validation. |

Copy the `merge-potential` value and preferred variant back to the **Decision** section of [the experiment record](2026-06-26-industrial-cognition-ab.md).

---

*Scorecard fields defined in [contract §8](2026-06-26-industrial-cognition-ab.contract.md#8-scorecard-fields-task-010). Scenario IDs frozen in [contract §5](2026-06-26-industrial-cognition-ab.contract.md#5-scenario-ids-the-shared-test-corpus) and implemented in `bridge/fixtures/`.*
