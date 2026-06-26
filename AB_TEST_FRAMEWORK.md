# Cogigator A/B Test Framework

Cogigator should evolve as a documented sequence of design contests, not as one prematurely merged implementation. This framework defines how to build a reusable shared substrate, run competing gameplay/UX variants on top of it, and preserve each experiment as part of the public development story.

## Core idea

Use one common technical foundation for many experiments:

```text
shared substrate
  ├─ Factorio mod scaffolding and stable runtime services
  ├─ common observation/report schema
  ├─ bridge API and fixtures
  ├─ Pi extension control surface
  └─ experiment hooks / variant interfaces

experiments
  ├─ A: design interpretation 1
  ├─ B: design interpretation 2
  └─ later C/D/... variants
```

The substrate should make it cheap to compare ideas without rewriting transport, reporting, Pi tools, or documentation from scratch.

## Why this matters

The project is itself an example of AI-assisted design exploration. The documentation should preserve that process:

- what was tested;
- why it was worth testing;
- which model/agent proposed it;
- what changed in the mod/bridge/Pi substrate;
- what the player experienced;
- what won, what lost, and what got merged;
- what the next contest should test.

The goal is not just to build a mod. The goal is to build a visible record of how competing AI-generated ideas survive contact with gameplay, implementation constraints, and human taste.

## Shared substrate doctrine

The substrate is the reusable kernel. It must be boring, stable, and conservative.

### Non-negotiables

1. **The Factorio mod is authoritative** for world state, permissions, and mutations.
2. **The bridge is a narrow adapter** for transport, reports, diagnostics, action intents, metrics, and provider calls.
3. **The Pi extension is a cockpit**: tools, commands, status, and approval UI. It is not a security boundary.
4. **Observation comes before mutation.** No experiment may bypass the read-only proof loop.
5. **Experiments must be switchable.** A player or test save should be able to select a variant without manually editing code.
6. **Experiment outputs must be comparable.** Every variant should produce common metrics and a standard write-up.
7. **No secrets in docs, code examples, sessions, logs, or committed config.**

### Substrate responsibilities

The substrate should own:

- mod lifecycle and storage migration patterns;
- entity registration helpers;
- rectangular worksite assignment and overlays;
- scan scheduling and tick budgets;
- bounded report generation;
- common derived finding vocabulary;
- report fixtures and replay support;
- bridge health/version/snapshot endpoints;
- Pi connection/status/snapshot tools;
- action-intent interfaces, even if disabled in early experiments;
- experiment selection and metadata;
- public documentation hooks.

### Variant responsibilities

A variant may own:

- names and fiction for in-game entities;
- capacity model and progression interpretation;
- datacenter mechanics;
- GUI copy and player-facing explanations;
- degradation rules;
- tuning formulas;
- what capabilities unlock at each tier;
- distinctive audiovisual/personality ideas;
- proposed future mutation/approval UX.

A variant must not own:

- raw transport protocols;
- secret handling;
- direct RCON exposure;
- permanent cluster deployment rules;
- unreviewed world mutation;
- unrelated documentation style.

## Initial A/B test: industrial cognition interpretations

### Shared hypothesis

Cogigator becomes more Factorio-native when AI capability is physically manufactured by the factory.

### Variant A: Sightline + Cognition Flow

Inspired by the Claude Opus plan.

Core interpretation:

- **Sightline** answers where the assistant can look.
- **Cognition** answers how hard it can think.
- Cores provide bounded observation zones.
- Datacenter machines produce a flow and buffer of Cognition.
- Memory Banks embody history/context.
- Low Cognition visibly throttles or queues analysis.

What to test:

- Is the two-scarcity model intuitive?
- Does Cognition as flow/buffer feel exciting or too abstract?
- Is the link between in-game compute and assistant capability legible?
- Does this produce memorable moments?

### Variant B: Field Station + Capacity Vector

Inspired by the GPT-5.5 plan.

Core interpretation:

- Field Stations observe worksites.
- Datacenter Cores aggregate compute infrastructure.
- Capacity is split into visible dimensions: scan, attention, memory, planning.
- Each capacity gates a class of capabilities.
- Rich multi-fluid compute machines arrive after a simple baseline works.

What to test:

- Is the capacity vector easier to understand than a single Cognition resource?
- Does it help players diagnose what to build next?
- Does it create too much UI/accounting?
- Does it scale better to future features?

### Common test scenarios

Each variant should be tested against the same small scenario set:

1. **Starved assembler** — input missing or belt empty.
2. **Blocked output** — product cannot leave a machine.
3. **Missing fluid** — machine waits on a fluid input.
4. **Low power** — electric network is under-supplied.
5. **Under-computed Cogigator** — observation exists but capability is degraded.
6. **Dense local cell** — report must truncate or omit honestly without hurting UPS.
7. **Player confusion probe** — can a human explain what to build next after reading the UI?

### Common metrics

Use qualitative and quantitative metrics.

| Metric | Type | Notes |
|---|---:|---|
| Time to first useful answer | quantitative | From placing/configuring the structure to receiving grounded diagnosis. |
| Report correctness | qualitative + count | Does the diagnosis match the actual scenario? |
| Player comprehension | qualitative | Can the player explain why the assistant is degraded? |
| Factorio-native feel | qualitative | Does it feel like logistics/infrastructure rather than a menu? |
| UPS/scan cost | quantitative | Basic timing and tick budget observations. |
| Implementation friction | qualitative | How many special cases did the variant require? |
| Documentation clarity | qualitative | Could the timeline explain the experiment compactly? |
| Merge potential | decision | Merge, iterate, park, or discard. |

## Standard experiment record

Every experiment should get a markdown record under:

```text
docs/experiments/YYYY-MM-DD-slug.md
```

Use this template:

```md
# Experiment: <name>

- Date:
- Status: proposed | running | completed | merged | parked | discarded
- Variants: A / B / C
- Agents/models involved:
- Related commits:
- Related resources:

## Question

What are we trying to learn?

## Shared substrate changes

What changed in common code/docs/schema to make this experiment possible?

## Variant descriptions

### Variant A — <name>

- Core idea:
- Player-facing fiction:
- Mechanics:
- Expected strengths:
- Expected weaknesses:

### Variant B — <name>

- Core idea:
- Player-facing fiction:
- Mechanics:
- Expected strengths:
- Expected weaknesses:

## Test scenarios

List scenario saves, fixtures, or manual setups.

## Results

Use the common metrics table.

## Decision

- Winner:
- Merge into substrate:
- Iterate next:
- Park/discard:

## Timeline summary

One short paragraph suitable for the public timeline.

## Safety/publication notes

Confirm no secrets, credentials, private IPs, raw cluster output, or sealed-secret contents are included.
```

## Suggested repository structure

This is a planning target, not a requirement for the current docs-only state.

```text
factorio-mod/
  common/
    storage.lua
    registry.lua
    worksites.lua
    reports.lua
    findings.lua
    experiments.lua
  variants/
    cognition-flow/
    capacity-vector/
  prototypes/
  locale/

bridge/
  src/
    api/
    transport/
    reports/
    experiments/
  fixtures/

.pi/
  extensions/
    cogigator/

docs/
  index.html
  experiments/
    TEMPLATE.md
    2026-06-26-industrial-cognition-ab.md
```

## Documentation loop

Each experiment should update the public story in three places:

1. **Experiment record** — full markdown detail under `docs/experiments/`.
2. **Timeline** — one condensed entry in `docs/index.html`.
3. **Comparison/report artifact** — optional visual report if the experiment produces a meaningful design fork.

The timeline should stay readable. It should not become a changelog of every implementation commit. It should capture turning points:

- a new hypothesis;
- a new shared substrate capability;
- a completed A/B result;
- a design decision;
- a public demo milestone.

## Fleet planning guidance

A fleet plan is feasible if agents have explicit ownership boundaries.

Recommended split for the first A/B implementation:

1. **Substrate agent**
   - Owns common mod scaffold, worksite model, report fixtures, and experiment registry.
   - Must not implement variant-specific tuning.

2. **Variant A agent**
   - Owns Sightline/Cognition Flow mechanics and UI copy.
   - Must use substrate interfaces.

3. **Variant B agent**
   - Owns Field Station/Capacity Vector mechanics and UI copy.
   - Must use substrate interfaces.

4. **Bridge/Pi agent**
   - Owns stub bridge, report endpoints, Pi read-only tools, and fake fixtures.
   - Must not encode variant policy except displaying variant metadata.

5. **Evaluation/docs agent**
   - Owns experiment record, timeline update, test rubric, and public-safe summary.
   - Must not modify core implementation files.

### File ownership principle

Avoid multiple agents editing the same files during the first pass. If shared files must change, the substrate agent owns them and variants request interface additions through small patches or notes.

## Definition of done for an A/B test

An A/B test is complete when:

- both variants run on the same substrate;
- both can be selected or demonstrated in the same environment;
- both produce comparable reports/metrics;
- the experiment record is filled out;
- the timeline has a public-safe summary entry;
- a decision is made: merge, iterate, park, or discard.

The winner does not need to be absolute. Often the right result will be a synthesis: one variant wins the fiction, another wins the UI, another wins implementation simplicity.
