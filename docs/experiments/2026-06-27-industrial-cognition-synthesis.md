# Experiment: Cognition Network Synthesis

- Date: 2026-06-27
- Status: running
- Variants: synthesis of `cognition-flow` and `capacity-vector`
- Agents/models involved: Pi, GPT-5.5
- Related commits:
  - `8abc48c` — read-only Cogigator A/B substrate spike
  - `c88860f` — Cognition Network synthesis brief and fixture wording
  - `42975de` — mod-side wording aligned with Cognition Network synthesis
  - `c778d11` — read-only Cognition Network entity shell
  - `7317264` — Field Station assigns a default read-only worksite
- Related resources:
  - [Industrial Cognition A/B experiment](2026-06-26-industrial-cognition-ab.md)
  - [A/B contract](2026-06-26-industrial-cognition-ab.contract.md)
  - [Runbook](2026-06-26-industrial-cognition-ab.runbook.md)
  - [Scorecard](2026-06-26-industrial-cognition-ab.scorecard.md)
  - [Safety/fairness review](2026-06-26-industrial-cognition-ab.review.md)

## Question

Can Cogigator keep the diagnostic clarity of **Capacity Vector** while adopting the stronger Factorio-native fiction of **Cognition Flow**?

The synthesis hypothesis: the player should understand explicit bottlenecks, but those bottlenecks should feel like an industrial network they built, powered, and saturated — not like a detached settings panel.

## Proposed synthesis: Cognition Network

**Cognition Network** is the player-facing umbrella mechanic.

- Field structures define where Cogigator can observe.
- Datacenter-like structures produce and route cognition capacity.
- The UI still exposes explicit capacity bottlenecks, but frames them as parts of one built network.
- Degraded reports explain both the mechanical capacity and the factory action implied by it.

## Player-facing entities

Working names:

| Entity | Role | Notes |
|---|---|---|
| Cogigator Core | Local anchor / early observation structure | Good for first prototype and compact cells. |
| Field Station | Worksite observer / remote sensor | Keeps Capacity Vector's clearer spatial metaphor. |
| Cognition Processor | Produces cognition throughput | Replaces vague “compute” with a manufacturable thing. |
| Memory Bank | Stores recent observations/history | Strong Factorio-friendly physicalization of context. |
| Planning Relay | Unlocks future plan/proposal capability | Remains read-only for now; no mutation path. |

## Capacity model

Internally keep the explicit capacity-vector shape because it explained bottlenecks well:

| Internal capacity | Player-facing wording | What the player should build/change |
|---|---|---|
| `scan` | Sightline / scan coverage | Add Field Stations or shrink/partition the worksite. |
| `attention` | Attention slots | Add/upgrade processors or reduce watched sites. |
| `memory` | Memory banks | Add Memory Banks or shorten history demand. |
| `planning` | Planning relay | Build/enable Planning Relay; still read-only until reviewed. |

Optional aggregate wording:

- “Cognition Network healthy” when all capacities are satisfied.
- “Cognition Network degraded” when any capacity bottleneck affects report quality.
- “Cognition supply insufficient” when multiple capacities are below demand.

## Snapshot copy direction

The Pi snapshot should continue to show concrete capacities, but with more factory-native notes.

Examples:

```text
✗ scan / Sightline: 1024/1600 tiles² [bottleneck]
    Worksite exceeds current Field Station coverage. Add stations or split the cell.

✗ attention / Attention: 1/3 slots [bottleneck]
    Cognition processors are saturated. Add processing or watch fewer sites.

✓ memory / Memory Banks: 8/6 units
    Recent observations are retained.

✓ planning / Planning Relay: 1/1 online
    Read-only planning advice is available.
```

## Test scenarios

Reuse the six existing fixture scenarios:

1. `starved-assembler`
2. `blocked-output`
3. `missing-fluid`
4. `low-power`
5. `under-computed`
6. `dense-cell-truncated`

Primary synthesis tests:

- `under-computed` — does the player know what to build to restore cognition?
- `dense-cell-truncated` — does truncation feel like a bounded factory system, not a bug?
- Scenario 7 manual probe — can a reader answer “what would you build or change next?” from the Pi output alone?

## Current prototype status

The synthesis prototype now has two read-only layers:

- bridge fixtures use Cognition Network language for degraded/truncated snapshots;
- mod-side variant helpers and locale strings point players toward concrete factory actions: add Field Stations, Cognition Processors, Memory Banks, or a Planning Relay;
- the Factorio mod defines an in-game entity shell for those four structures so the network can be placed and discussed in-game;
- runtime code observes Field Station placement/removal, updates registry counts, and assigns/releases one default 32×32 read-only worksite;
- local Windows Factorio smoke testing confirmed placement shows `stations=1 worksites=1`, `/cogigator-worksites` prints bounds, and removal returns to `stations=0 worksites=0`;
- no schema, bridge API, live bridge connection, assistant action, or world-mutation behavior changed.

## Acceptance criteria

- Same bridge/Pi path remains read-only and variant-agnostic.
- No live Factorio/Kubernetes validation required yet.
- No assistant mutation path exists.
- Placing/removing the new entity shell is normal player-driven Factorio behavior; Cogigator only observes Field Station placement for status counts.
- Pi output names the degraded capacity and suggests a factory action.
- The manual comprehension probe succeeds for at least one degraded scenario.
- The scorecard can be updated without inventing a third schema.

## Decision to make after prototype

| Question | Possible outcomes |
|---|---|
| Does Cognition Network improve readability over either original variant? | merge / iterate / park |
| Are explicit capacities still visible enough? | keep all / hide some / rename |
| Does the fiction feel Factorio-native? | proceed / revise entity names / revise resource model |
| Is live mod testing worth doing next? | yes after review / no, continue fixtures |

## Timeline summary

After the first A/B spike passed the local integration gate, the next iteration became **Cognition Network**: explicit capacity bottlenecks framed as a built, powered, saturating factory system. The first in-game shell now exists and has been locally smoke-tested: Field Stations create read-only 32×32 worksites, while the bridge/Pi path remains fixture-backed until a later reviewed integration phase.

## Safety/publication notes

This synthesis brief contains no secrets, credentials, private IPs, raw cluster output, sealed-secret contents, deployment instructions, or assistant mutation path. Local Factorio testing was performed on a private Windows test save; no live server or Kubernetes validation was performed.
