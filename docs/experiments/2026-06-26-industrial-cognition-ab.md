# Experiment: Industrial Cognition Interpretations

- Date: 2026-06-26
- Status: proposed
- Variants: A — Sightline + Cognition Flow; B — Field Station + Capacity Vector
- Agents/models involved: Claude Opus 4.8, GPT-5.5, Pi
- Related commits: concept/plans/report timeline commits before first implementation
- Related resources:
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

Initial shared scenarios:

1. Starved assembler.
2. Blocked output.
3. Missing fluid.
4. Low power.
5. Under-computed Cogigator/datacenter.
6. Dense local cell requiring honest truncation/omission.
7. Human comprehension probe: can the player explain what to build next?

## Results

Not run yet.

| Metric | Variant A | Variant B | Notes |
|---|---|---|---|
| Time to first useful answer | TBD | TBD | |
| Report correctness | TBD | TBD | |
| Player comprehension | TBD | TBD | |
| Factorio-native feel | TBD | TBD | |
| UPS/scan cost | TBD | TBD | |
| Implementation friction | TBD | TBD | |
| Documentation clarity | TBD | TBD | |
| Merge potential | TBD | TBD | |

## Decision

- Winner: TBD
- Merge into substrate: TBD
- Iterate next: TBD
- Park/discard: TBD

## Timeline summary

The next contest is defined: build a reusable shared Cogigator substrate, then test two interpretations of industrialized cognition on top of it — one built around Sightline and Cognition flow, the other around Field Stations and explicit capacity vectors.

## Safety/publication notes

This experiment record contains no secrets, credentials, private IPs, raw cluster output, or sealed-secret contents. Infrastructure is referenced only at the non-sensitive level already documented in the repository.
