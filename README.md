# Cogigator

**Cogigator** is a Factorio 2.0 / Space Age mod and companion-system concept: an in-world, physically bounded machine intelligence that observes local production cells, diagnoses problems from real game state, and eventually proposes changes only with explicit player approval.

This repository currently contains the **planning and read-only spike artifacts** for Cogigator. The current implementation work is fixture-based and local; it is not deployed to a live Factorio server and does not mutate a world.

## Public project page

- Development timeline: <https://mtrenker.github.io/cogigator/>
- Visual plan comparison: <https://mtrenker.github.io/cogigator/PLAN_REPORT.html>

## Current status

The project has moved from concept and architecture into the first shared-substrate A/B spike.

What exists now:

- a concept brief;
- non-sensitive infrastructure context for the existing Factorio/Kubernetes environment;
- Pi extension integration notes;
- two competing implementation plans from different models;
- a visual comparison report;
- a reusable A/B testing framework for future design contests;
- a frozen A/B spike contract;
- a local read-only bridge stub and deterministic fixture corpus;
- two variant modules for the first industrial cognition comparison;
- a demo runbook, scoring worksheet, and safety review note;
- a GitHub Pages timeline documenting the process.

No live server integration, cluster deployment, or world mutation path exists in this spike.

## Why this repo exists

The project is intentionally documenting the way AI is being used:

1. capture an open-ended concept;
2. add real-world infrastructure constraints;
3. ask multiple models for competing plans;
4. compare the plans visually and structurally;
5. turn promising differences into A/B tests;
6. preserve the whole process as a public development timeline.

The goal is not only to build a mod. The goal is to show how AI-assisted planning can become a visible, reviewable, iterative engineering artifact.

## Key resources

| File | Purpose |
|---|---|
| [`CONCEPT_BRIEF.md`](./CONCEPT_BRIEF.md) | The core Cogigator fantasy and design space. |
| [`INFRASTRUCTURE.md`](./INFRASTRUCTURE.md) | Non-sensitive context about the existing Pacabytes Kubernetes + Factorio setup. |
| [`PI.md`](./PI.md) | Notes on Pi's extension system and how Cogigator should integrate with it. |
| [`PLAN.claude-opus-4-8.md`](./PLAN.claude-opus-4-8.md) | Claude Opus implementation plan. |
| [`PLAN.gpt-5.5.md`](./PLAN.gpt-5.5.md) | GPT-5.5 implementation plan. |
| [`PLAN_REPORT.html`](./PLAN_REPORT.html) | Self-contained visual comparison report. |
| [`AB_TEST_FRAMEWORK.md`](./AB_TEST_FRAMEWORK.md) | Reusable framework for shared-substrate A/B tests. |
| [`PLAN.md`](./PLAN.md) | Fleet-compatible implementation plan for the first shared-substrate A/B spike. |
| [`docs/experiments/2026-06-26-industrial-cognition-ab.contract.md`](./docs/experiments/2026-06-26-industrial-cognition-ab.contract.md) | Frozen schema and invariants for the first spike. |
| [`docs/experiments/2026-06-26-industrial-cognition-ab.runbook.md`](./docs/experiments/2026-06-26-industrial-cognition-ab.runbook.md) | Local read-only demo loop for both variants. |
| [`docs/experiments/2026-06-26-industrial-cognition-ab.scorecard.md`](./docs/experiments/2026-06-26-industrial-cognition-ab.scorecard.md) | Evaluation worksheet for scoring the variants. |
| [`docs/experiments/2026-06-26-industrial-cognition-ab.review.md`](./docs/experiments/2026-06-26-industrial-cognition-ab.review.md) | Public-safety and variant-fairness review gate. |
| [`docs/experiments/2026-06-27-industrial-cognition-synthesis.md`](./docs/experiments/2026-06-27-industrial-cognition-synthesis.md) | Cognition Network synthesis brief for the next iteration. |
| [`docs/experiments/2026-06-27-industrial-cognition-synthesis.probe.md`](./docs/experiments/2026-06-27-industrial-cognition-synthesis.probe.md) | Manual human comprehension probe for the synthesis. |
| [`docs/experiments/2026-06-27-live-local-snapshot-runbook.md`](./docs/experiments/2026-06-27-live-local-snapshot-runbook.md) | Local-only live read-only snapshot export/import runbook. |
| [`docs/experiments/2026-06-27-blueprint-proposal-mode.md`](./docs/experiments/2026-06-27-blueprint-proposal-mode.md) | Proposal-only blueprint drafting prototype. |
| [`docs/experiments/2026-06-27-blueprint-draftsman-skill.md`](./docs/experiments/2026-06-27-blueprint-draftsman-skill.md) | Deterministic blueprint drafting workflow and first red science template. |
| [`docs/DEVELOPMENT_PROCESS.md`](./docs/DEVELOPMENT_PROCESS.md) | How the AI-assisted documentation/planning workflow works. |
| [`docs/experiments/`](./docs/experiments/) | Standardized experiment records. |

## Design direction in one paragraph

Cogigator should feel like **industrialized cognition**. The player does not get an omniscient chatbot for free. They build local observation structures and datacenter-like compute infrastructure. That infrastructure determines what the assistant can see, how hard it can think, how much history it can retain, how many sites it can watch, and what kinds of plans it may propose.

## Current architectural consensus

The two competing plans differ in emphasis, but agree on the safe core:

```text
Pi extension / operator cockpit
  -> Cogigator bridge API
    -> Factorio mod runtime
      -> authoritative world state and all approved mutations
```

Principles:

- The **Factorio mod** owns world truth, permission state, and any future mutation.
- The **bridge** is a narrow adapter for transport, snapshots, diagnostics, action intents, metrics, and provider calls.
- The **Pi extension** provides safe model tools, commands, status, and approval UI.
- The first milestone should prove read-only grounded diagnostics before any mutation path exists.

## First proposed A/B test

The first planned design contest compares two interpretations of the datacenter mechanic:

- **Variant A — Sightline + Cognition Flow**
  - Cores provide local sightline.
  - Datacenter machines manufacture Cognition as a flow/buffer.
  - Memory banks become physical context/history.

- **Variant B — Field Station + Capacity Vector**
  - Field Stations observe worksites.
  - Datacenter Core aggregates explicit capacities: scan, attention, memory, planning.
  - Each capacity gates a class of assistant capabilities.

The spike now has a public-safe read-only substrate: a frozen contract, synthetic scenarios, a local bridge stub, Pi-facing read/status tools, a runbook, a scorecard, a completed safety/fairness review, and a locally tested Pi snapshot display for degraded/truncated scenarios.

See [`AB_TEST_FRAMEWORK.md`](./AB_TEST_FRAMEWORK.md), [`docs/experiments/2026-06-26-industrial-cognition-ab.md`](./docs/experiments/2026-06-26-industrial-cognition-ab.md), [`docs/experiments/2026-06-26-industrial-cognition-ab.contract.md`](./docs/experiments/2026-06-26-industrial-cognition-ab.contract.md), [`docs/experiments/2026-06-26-industrial-cognition-ab.runbook.md`](./docs/experiments/2026-06-26-industrial-cognition-ab.runbook.md), [`docs/experiments/2026-06-26-industrial-cognition-ab.scorecard.md`](./docs/experiments/2026-06-26-industrial-cognition-ab.scorecard.md), and [`docs/experiments/2026-06-26-industrial-cognition-ab.review.md`](./docs/experiments/2026-06-26-industrial-cognition-ab.review.md).

## Publication and docs

GitHub Pages is deployed by `.github/workflows/pages.yml` using GitHub Actions. The workflow builds a static `_site` artifact containing:

- the timeline page under `docs/`;
- the linked markdown resources from the repository root;
- the visual report;
- experiment records.

The root `index.html` redirects to `docs/`, so both of these should work after deployment:

- <https://mtrenker.github.io/cogigator/>
- <https://mtrenker.github.io/cogigator/docs/>

## Safety boundary

This repo is intended to be public-safe.

Do not commit:

- passwords;
- API keys or model provider credentials;
- RCON passwords;
- private keys;
- raw Kubernetes secret values;
- sealed-secret decrypted contents;
- private IPs or sensitive live cluster output;
- local `.pi` runtime config containing endpoints or credentials.

Infrastructure may be discussed only at the non-sensitive level already used in [`INFRASTRUCTURE.md`](./INFRASTRUCTURE.md).

## Suggested next step

The local read-only integration check passed, the [Cognition Network synthesis](./docs/experiments/2026-06-27-industrial-cognition-synthesis.md) has a local in-game shell, and the bridge can ingest a local live snapshot. The current prototype is [Blueprint Proposal Mode](./docs/experiments/2026-06-27-blueprint-proposal-mode.md). The first [Blueprint Draftsman workflow](./docs/experiments/2026-06-27-blueprint-draftsman-skill.md) failed practical layout validation, so the next iteration is a [Semantic Blueprint Planner](./docs/experiments/2026-06-27-semantic-blueprint-planner.md): deterministic generation with belt connectivity, inserter pickup/drop, blocked tile, and recipe validation.
