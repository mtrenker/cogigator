# Development Process

This document records the AI-assisted workflow used to create the initial Cogigator planning repository. It is meant to be reusable for future sessions, experiments, and implementation work.

## The pattern

Cogigator is being developed as a public, documented sequence of AI-assisted design loops:

```text
idea
  -> concept brief
  -> real constraints
  -> model contest
  -> comparison artifact
  -> shared-substrate experiment
  -> implementation result
  -> timeline update
```

The important part is that the reasoning process becomes part of the repository. Plans, comparisons, experiment records, and timeline entries are first-class artifacts, not disposable chat history.

## What happened in the initial session

### 1. Capture the concept

A high-level idea became [`CONCEPT_BRIEF.md`](../CONCEPT_BRIEF.md): Cogigator as a Factorio-native machine intelligence rather than a generic chatbot.

Key concept decisions:

- local, bounded observation;
- in-world structures;
- player approval for actions;
- industrialized cognition as a gameplay direction;
- datacenter infrastructure as a real Factorio cost.

### 2. Add real infrastructure context

The existing Pacabytes Factorio/Kubernetes setup was summarized in [`INFRASTRUCTURE.md`](../INFRASTRUCTURE.md).

This changed the planning quality because models had to account for:

- a live headless Factorio server;
- Kubernetes and ArgoCD/GitOps deployment;
- internal RCON service;
- sealed-secret patterns;
- avoiding public control surfaces;
- avoiding unnecessary StatefulSet disruption.

The document intentionally excludes sensitive details.

### 3. Document Pi integration

Pi's extension system was summarized in [`PI.md`](../PI.md).

This established the control-surface pattern:

```text
Pi extension
  -> bridge API
    -> Factorio mod authority
```

It also captured practical Pi extension constraints:

- tools and commands;
- event hooks;
- UI prompts and status widgets;
- session state;
- non-interactive fail-closed behavior;
- not putting game-control logic directly inside the extension.

### 4. Run a model contest

Two models were asked to revise their implementation plans using the same source material:

- [`PLAN.claude-opus-4-8.md`](../PLAN.claude-opus-4-8.md)
- [`PLAN.gpt-5.5.md`](../PLAN.gpt-5.5.md)

They were intentionally given room to interpret rather than being forced into one solution.

The result was useful because the models emphasized different strengths:

- Claude Opus: infrastructure posture, RCON-first safety, Cognition as the central mechanic.
- GPT-5.5: product taxonomy, capacity model, staged implementation, testing structure.

### 5. Create a comparison artifact

The two plans were turned into [`PLAN_REPORT.html`](../PLAN_REPORT.html), a self-contained visual comparison report.

This converted planning text into a reviewable artifact with:

- plan cards;
- radar comparison;
- phase timeline;
- architecture diagram;
- comparison table;
- risk heatmap;
- recommended synthesis.

### 6. Preserve the process in git

The repository was initialized with one commit per major process step, so the history itself reads like a development walkthrough.

The initial sequence:

1. safeguards;
2. concept brief;
3. infrastructure context;
4. Pi context;
5. Claude plan;
6. GPT plan;
7. visual comparison;
8. Pages timeline;
9. Pages workflow;
10. publication setup;
11. A/B framework.

This is deliberate. Future work should continue to use meaningful commits that preserve the story.

### 7. Publish a timeline

A GitHub Pages site was created in [`docs/index.html`](./index.html), backed by `.github/workflows/pages.yml`.

The site is not just marketing. It is a condensed public build log that links back to the source artifacts.

### 8. Define the experiment loop

The project then generalized the model contest into a reusable A/B testing framework:

- [`AB_TEST_FRAMEWORK.md`](../AB_TEST_FRAMEWORK.md)
- [`docs/experiments/TEMPLATE.md`](./experiments/TEMPLATE.md)
- [`docs/experiments/2026-06-26-industrial-cognition-ab.md`](./experiments/2026-06-26-industrial-cognition-ab.md)

The new doctrine: build a shared substrate once, then run multiple competing gameplay/UX interpretations on top of it.

## Standard workflow for future sessions

Use this loop for major changes:

1. **State the question**
   - What are we trying to learn or build?
   - Is this a substrate change, a variant, an evaluation, or documentation?

2. **Read the source artifacts**
   - `README.md`
   - `CONCEPT_BRIEF.md`
   - `INFRASTRUCTURE.md`
   - `PI.md`
   - `AB_TEST_FRAMEWORK.md`
   - relevant experiment records

3. **Preserve safety boundaries**
   - no secrets;
   - no raw credentials;
   - no public RCON exposure;
   - no unreviewed mutation paths;
   - no unnecessary cluster changes.

4. **Prefer shared substrate first**
   - If two variants need the same helper, put it in the substrate.
   - If a decision is variant-specific, keep it out of the substrate.

5. **Use model competition intentionally**
   - Ask different models for distinct interpretations.
   - Do not over-constrain them into one answer too early.
   - Compare outputs against real constraints and player experience.

6. **Document the experiment**
   - Add or update a file under `docs/experiments/`.
   - Include question, variants, substrate changes, scenarios, results, decision, and timeline summary.

7. **Update the public timeline only for turning points**
   - new hypothesis;
   - completed experiment;
   - substrate milestone;
   - implementation demo;
   - design decision.

8. **Commit in story-sized steps**
   - One commit should represent one comprehensible process step.
   - Avoid dumping unrelated implementation and documentation changes into the same commit unless the documentation describes that implementation step.

## Commit style

Prefer messages like:

```text
Add Cogigator concept brief
Document Pi extension integration context
Add visual comparison report
Define reusable A/B test framework
Implement shared worksite substrate
Record industrial cognition A/B results
```

Avoid vague messages like:

```text
update
fix stuff
more docs
changes
```

## Experiment documentation standard

Every meaningful A/B test should have:

- an experiment markdown record in `docs/experiments/`;
- a clear status: proposed, running, completed, merged, parked, discarded;
- links to relevant commits and resources;
- standardized metrics;
- a decision section;
- a public-safe timeline summary.

Use [`docs/experiments/TEMPLATE.md`](./experiments/TEMPLATE.md).

## Fleet planning pattern

For implementation contests, use clear file ownership:

1. **Substrate agent**
   - common mod/bridge/Pi interfaces;
   - worksite model;
   - reports and fixtures.

2. **Variant agents**
   - gameplay interpretation;
   - tuning;
   - UI copy;
   - variant-specific docs.

3. **Bridge/Pi agent**
   - bridge endpoints;
   - Pi tools and commands;
   - stub/fake data loops.

4. **Evaluation/docs agent**
   - experiment record;
   - metrics;
   - timeline update;
   - public-safe summary.

Avoid multiple agents editing the same files without an explicit ownership plan.

## Publication workflow

GitHub Pages is deployed with GitHub Actions from `.github/workflows/pages.yml`.

When adding a new root-level artifact that should be linked from the site, update the workflow so it copies the file into `_site`.

Files under `docs/` are copied recursively.

## Public-safety checklist

Before committing or publishing documentation, check that it contains no:

- passwords;
- model provider API keys;
- GitHub tokens;
- RCON passwords;
- private keys;
- raw secret values;
- decrypted sealed-secret contents;
- private IPs;
- sensitive live cluster output;
- local machine-specific credentials.

Mentioning high-level patterns is okay, for example:

- Kubernetes;
- ArgoCD;
- GitOps;
- internal RCON service;
- sealed-secret workflow;
- private/Tailscale access path.

Do not include actual secret material or sensitive runtime output.

## Current next step

The recommended next step is to execute [`../FLEET_PLAN.md`](../FLEET_PLAN.md), the fleet-compatible plan for the first A/B implementation:

- build the shared substrate;
- implement Variant A: Sightline + Cognition Flow;
- implement Variant B: Field Station + Capacity Vector;
- create bridge/Pi read-only tooling;
- evaluate both against shared scenarios;
- update the experiment record and public timeline.

The first implementation milestone should remain read-only and should not require persistent cluster changes.
