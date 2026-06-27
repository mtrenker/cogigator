# Experiment: Industrial Cognition Interpretations

- Date: 2026-06-26
- Status: local integration checked
- Variants: A — Sightline + Cognition Flow; B — Field Station + Capacity Vector
- Agents/models involved: Claude Opus 4.8, GPT-5.5, Pi
- Related commits: concept/plans/report timeline commits before first implementation
- Related resources:
  - [Implementation contract](2026-06-26-industrial-cognition-ab.contract.md) — frozen field names, schema versions, scorecard keys
  - [Demo runbook](2026-06-26-industrial-cognition-ab.runbook.md) — step-by-step local A/B loop
  - [Scoring worksheet](2026-06-26-industrial-cognition-ab.scorecard.md) — fill in after demo run
  - [Concept brief](../../CONCEPT_BRIEF.md)
  - [Infrastructure context](../../INFRASTRUCTURE.md)
  - [Pi extension context](../../PI.md)
  - [Claude Opus plan](../../PLAN.claude-opus-4-8.md)
  - [GPT-5.5 plan](../../PLAN.gpt-5.5.md)
  - [Visual comparison report](../../PLAN_REPORT.html)
  - [A/B framework](../../AB_TEST_FRAMEWORK.md)

## Question

Which gameplay interpretation makes Cogigator feel most Factorio-native while staying implementable on a shared substrate?

The shared hypothesis is that AI capability should be physically manufactured by the factory. The contest is about the clearest and most exciting way to express that.

## Shared substrate changes

Proposed substrate capabilities for the test:

- Factorio mod scaffold;
- placed observation structure;
- rectangular worksite assignment;
- scan scheduling and bounded report generation;
- common derived findings;
- bridge stub/API for status and snapshots;
- Pi read-only status/snapshot tools;
- experiment metadata and variant selection;
- fixtures for replay and comparison.

No world mutation is part of this experiment.

## Variant descriptions

### Variant A — Sightline + Cognition Flow

- Core idea: Cogigator is governed by two scarcities: where it can look and how hard it can think.
- Player-facing fiction: Cores provide sightline; datacenter machines manufacture Cognition flow and buffer.
- Mechanics: Cognition affects report freshness, analysis depth, watches, and overload/degraded states.
- Expected strengths: memorable fiction; strong thematic link between factory infrastructure and AI capability; can later map to real model budget.
- Expected weaknesses: a single abstract resource may hide what the player should build next.

### Variant B — Field Station + Capacity Vector

- Core idea: Cogigator capability is split into explicit capacities.
- Player-facing fiction: Field Stations observe worksites while a Datacenter Core aggregates scan, attention, memory, and planning capacity.
- Mechanics: different capacities gate different capability classes.
- Expected strengths: clearer UI and tuning knobs; easier to explain bottlenecks; strong testing structure.
- Expected weaknesses: may feel more like a management panel than a strange industrial mind.

## Test scenarios

Six fixture scenarios (IDs frozen in [contract §5](2026-06-26-industrial-cognition-ab.contract.md); fixtures in `bridge/fixtures/`):

1. `starved-assembler` — assembler input missing / feed belt empty.
2. `blocked-output` — product cannot leave a machine.
3. `missing-fluid` — machine waits on a fluid input.
4. `low-power` — electric network under-supplied.
5. `under-computed` — observation exists but cognition/capacity is degraded.
6. `dense-cell-truncated` — many entities; report must truncate honestly.

Scenario 7 (no fixture): Human comprehension probe — can the player explain what to build next after reading the analyze output? See [scorecard §Scenario 7](2026-06-26-industrial-cognition-ab.scorecard.md#scenario-7-comprehension-probe-manual--no-fixture).

## Results

Local integration check completed on 2026-06-26 using the [runbook](2026-06-26-industrial-cognition-ab.runbook.md). The bridge served both variants through the same `/snapshot` and `/analyze` paths for all six fixture scenarios; the focused Task 013 check also exercised `starved-assembler` and `under-computed` end-to-end across both variants.

The subjective human scoring worksheet remains the tool for a later player-facing evaluation, but the mechanical gate passed: shared reports are comparable, deterministic diagnoses match the frozen fixtures, no mutation route is exposed, and the Task 011 public-safety/fairness review remains PASS.

Summary:

| Metric | Weight | Variant A (`cognition-flow`) | Variant B (`capacity-vector`) | Notes |
|---|---:|---|---|---|
| `player-comprehension` | 20 | Not human-scored | Not human-scored | Requires Scenario 7 human probe. |
| `factorio-native-feel` | 18 | Not human-scored | Not human-scored | Subjective; defer to next playtest. |
| `diagnostic-usefulness` | 20 | Pass | Pass | `primaryFindingCode` matched fixture expectation in 6/6 scenarios for both variants. |
| `degradation-clarity` | 14 | Pass mechanically | Pass mechanically | `under-computed` and `dense-cell-truncated` expose degraded/truncated state through shared fields. |
| `fun-inspiration` | 12 | Not human-scored | Not human-scored | Requires player reaction. |
| `implementation-friction` | 8 | Pass | Pass | Both use the generic bridge/report path. |
| `future-extensibility` | 8 | Candidate | Candidate | Both remain viable; synthesize before choosing one metaphor. |
| **Weighted total** | **100** | **Not computed** | **Not computed** | Human scoring still required for a numeric winner. |
| `time-to-first-useful-answer` | — | Local smoke only | Local smoke only | Fixture-backed; not timed as a human demo. |
| `report-correctness` | — | 6/6 | 6/6 | supporting metric |
| `ups-scan-cost` | — | N/A | N/A | fixture-based spike |
| `documentation-clarity` | — | Pass | Pass | Contract/runbook/scorecard/review are linked from public docs. |

## Decision

- Winner: Synthesize (no single numeric winner yet; both variants passed the integration gate).
- Next step: synthesize.
- `merge-potential`: iterate (`merge` | `iterate` | `park` | `discard`) — keep the shared substrate, then combine the clearer capacity-vector diagnostics with the stronger cognition-flow fiction before live validation.
- Merge into substrate: merge the variant-agnostic read-only substrate concepts only; do not merge a world mutation path.
- Iterate next: create a synthesis proposal/playtest that maps explicit capacities to a more Factorio-native manufactured Cognition presentation, then run the manual comprehension probe.
- Park/discard: park live Kubernetes validation and real Factorio server deployment until after the synthesized read-only prototype is reviewed.

## Timeline summary

The first contest has a tested local substrate: both interpretations run through the same read-only bridge and Pi extension path, including degraded and truncated snapshots. The decision is to synthesize next rather than crown a winner before human comprehension scoring.

## Safety/publication notes

This experiment record contains no secrets, credentials, private IPs, raw cluster output, or sealed-secret contents. Infrastructure is referenced only at the non-sensitive level already documented in the repository.
