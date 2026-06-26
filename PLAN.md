# Plan: Shared-Substrate A/B Implementation Spike for Cogigator

## Overview

This plan implements the first Cogigator A/B test as a **read-only spike**: one shared substrate, two competing gameplay interpretations, one bridge API, and one Pi integration. The goal is not to ship the final mod. The goal is to make both revised plans testable against the same observation/report pipeline so the project can compare gameplay clarity, implementation friction, and player-facing feel.

The selected scope is a spike/prototype. That means the plan prioritizes learning, small runnable slices, fixtures, and clear evaluation over production hardening. ⚠ skipped (spike): world mutation, real cluster deployment, secret management, authenticated public endpoints, full Factorio art/icons, multiplayer permission polish, and UDP/sidecar transport. These are intentionally deferred until the read-only loop proves valuable.

The key architectural decision is: **one Factorio mod substrate with variant modules**, not two separate mods. Variant A implements the Claude-inspired **Sightline + Cognition Flow** interpretation. Variant B implements the GPT-inspired **Field Station + Capacity Vector** interpretation. Both variants use the same report schema, same bridge endpoints, same Pi tools, same scenarios, and same evaluation rubric.

## Shared boundaries

- The Factorio mod remains authoritative for world state, observations, experiment metadata, and any future mutation.
- The bridge is a narrow local/stub API for health, variant metadata, fixtures, snapshots, and deterministic analysis packaging.
- The Pi extension is variant-agnostic. It displays variant metadata but does not encode gameplay policy.
- No task may add a real world-mutation path. Any action intent type must remain inert and explicitly disabled.
- No task may include secrets, credentials, private IPs, raw cluster output, RCON passwords, model provider keys, or sealed-secret contents.

## Proposed repository structure

```text
factorio-mod/
  cogigator/
    info.json
    data.lua
    control.lua
    settings.lua
    prototypes/
      entities.lua
      items.lua
      recipes.lua
      technologies.lua
    scripts/
      common/
        experiments.lua
        registry.lua
        worksites.lua
        reports.lua
        findings.lua
        metrics.lua
      variants/
        cognition-flow.lua
        capacity-vector.lua
    locale/en/cogigator.cfg

bridge/
  package.json or pyproject.toml
  src/
    server.*
    fixtures.*
    schema.*
  fixtures/
    starved-assembler.json
    blocked-output.json
    missing-fluid.json
    low-power.json
    under-computed.json
    dense-cell-truncated.json

.pi/extensions/cogigator/index.ts

docs/experiments/2026-06-26-industrial-cognition-ab.md
```

Final language/framework choices for `bridge/` may be selected by Task 007. Keep it local-first and dependency-light.

## Challenges & tradeoffs

- **One mod with variant modules vs two separate mods:** one mod is better for fair A/B testing because bridge/Pi/report behavior stays identical. The tradeoff is that the substrate must be designed carefully enough that variant code does not contaminate common code.
- **Fixtures first vs live Factorio first:** fixtures first are faster and safer, but risk missing Factorio API details. The plan therefore builds fixtures and a minimal Factorio mod scaffold in parallel, then connects them through the same schema.
- **Abstract capacity vs physical simulation:** the spike should expose enough capacity/degradation state to compare designs, but should not build full fluid/cooling simulation yet. ⚠ skipped (spike): real multi-fluid machine behavior and full balancing curves.
- **Pi integration early vs later:** adding Pi early ensures the shared integration remains variant-agnostic. The tradeoff is that Pi tools will initially talk to fixture/stub bridge data rather than live RCON.

## Tasks

### Task 001: Verify implementation assumptions and finalize spike contracts

- **engine**: claude
- **profile**: deep
- **thinking**: high
- **agent**: scout
- **depends**: none
- **description**: Read `README.md`, `CONCEPT_BRIEF.md`, `AB_TEST_FRAMEWORK.md`, `PLAN.claude-opus-4-8.md`, `PLAN.gpt-5.5.md`, `PI.md`, and `docs/experiments/2026-06-26-industrial-cognition-ab.md`. Produce `docs/experiments/2026-06-26-industrial-cognition-ab.contract.md` defining the shared snapshot shape, variant metadata fields, scenario IDs, and scorecard fields for the spike; acceptance criterion is that later tasks can implement against this contract without reading the planning chat.

### Task 002: Scaffold the shared Factorio mod substrate

- **engine**: claude
- **profile**: balanced
- **thinking**: high
- **agent**: worker
- **depends**: 001
- **description**: Create `factorio-mod/cogigator/` with `info.json`, `data.lua`, `control.lua`, `settings.lua`, `prototypes/`, `scripts/common/`, `scripts/variants/`, and `locale/en/cogigator.cfg`. Use Task 001's contract to add a variant registry in `scripts/common/experiments.lua`, a station/worksite registry stub in `scripts/common/registry.lua` and `scripts/common/worksites.lua`, and no-op report/metrics modules; acceptance criterion is that the mod structure is valid-looking, variant-selectable by setting/command stub, and contains no world mutation path.

### Task 003: Build shared report fixtures and deterministic scenario corpus

- **engine**: codex
- **profile**: balanced
- **thinking**: medium
- **agent**: worker
- **depends**: 001
- **description**: Create `bridge/fixtures/` with JSON fixtures for `starved-assembler`, `blocked-output`, `missing-fluid`, `low-power`, `under-computed`, and `dense-cell-truncated` using the snapshot/report contract from Task 001. Each fixture must include `experimentId`, `variantId`, station/worksite metadata, tick, capacity/degradation block, findings, omitted/truncation markers, and expected diagnosis notes; acceptance criterion is that both variants can be represented by the same fixture schema.

### Task 004: Implement Variant A — Sightline + Cognition Flow module

- **engine**: claude
- **profile**: balanced
- **thinking**: high
- **agent**: worker
- **depends**: 001, 002
- **description**: Add `factorio-mod/cogigator/scripts/variants/cognition-flow.lua` and any variant-specific locale entries needed for the Claude-inspired Sightline + Cognition Flow interpretation. Use Task 001's contract for field names and build on Task 002's variant registry to expose a pure-data variant descriptor plus capacity/degradation functions for `sightline`, `cognitionFlow`, `cognitionBuffer`, `memory`, and `overloaded`; acceptance criterion is that the common substrate can select this variant and produce variant metadata without changing common report code.

### Task 005: Implement Variant B — Field Station + Capacity Vector module

- **engine**: codex
- **profile**: balanced
- **thinking**: medium
- **agent**: worker
- **depends**: 001, 002
- **description**: Add `factorio-mod/cogigator/scripts/variants/capacity-vector.lua` and any variant-specific locale entries needed for the GPT-inspired Field Station + Capacity Vector interpretation. Use Task 001's contract for field names and build on Task 002's variant registry to expose a pure-data variant descriptor plus capacity/degradation functions for `scan`, `attention`, `memory`, and `planning`; acceptance criterion is that the common substrate can select this variant and produce variant metadata without changing common report code.

### Task 006: Implement common report generation against variant interfaces

- **engine**: claude
- **profile**: deep
- **thinking**: high
- **agent**: worker
- **depends**: 001, 002, 004, 005
- **description**: Implement `scripts/common/reports.lua`, `scripts/common/findings.lua`, and `scripts/common/metrics.lua` so they call the selected variant module through the shared interface and emit the Task 001 snapshot shape. Use Task 002's common module layout plus the variant interfaces from Task 004 and Task 005; acceptance criterion is that both Variant A and Variant B produce comparable reports with different capacity/degradation explanations and identical finding vocabulary. For the spike, reports may use synthetic in-mod data or fixture-like deterministic tables rather than live entity scans. ⚠ skipped (spike): full `surface.find_entities_filtered` scanning and UPS tuning.

### Task 007: Create local bridge stub with variant-agnostic API

- **engine**: codex
- **profile**: balanced
- **thinking**: medium
- **agent**: worker
- **depends**: 001, 003
- **description**: Implement a lightweight local bridge under `bridge/` with endpoints `GET /health`, `GET /version`, `GET /experiments/current`, `GET /scenarios`, `GET /snapshot?scenarioId=...&variantId=...`, and `POST /analyze`. Use Task 001's API/snapshot contract and Task 003's fixtures as the backing store, keeping the API variant-agnostic; acceptance criterion is that `curl` can retrieve both variants for each shared scenario and `/analyze` returns deterministic cited findings, not LLM output. ⚠ skipped (spike): RCON, Kubernetes deployment, authentication, and provider API calls.

### Task 008: Implement variant-agnostic Pi extension tools against the bridge

- **engine**: claude
- **profile**: balanced
- **thinking**: high
- **agent**: worker
- **depends**: 001, 007
- **description**: Create `.pi/extensions/cogigator/index.ts` with read-only commands/tools `cogigator_status`, `cogigator_snapshot`, `cogigator_analyze`, `/cogigator-connect`, `/cogigator-status`, `/cogigator-snapshot`, and `/cogigator-experiment`. Use Task 001's field contract and the bridge API from Task 007 to display `experimentId`, `variantId`, scenario, station, tick, findings, and degradation state without encoding variant-specific policy; acceptance criterion is that Pi can query both variants through the same tool path and no tool can mutate game state. ⚠ skipped (spike): approval UI, action intents, event streams, and port-forward management.

### Task 009: Add experiment selection and local demo instructions

- **engine**: codex
- **profile**: fast
- **thinking**: medium
- **agent**: worker
- **depends**: 004, 005, 007, 008
- **description**: Add `docs/experiments/2026-06-26-industrial-cognition-ab.runbook.md` documenting how to run the bridge stub from Task 007, load/query the two variant modules from Task 004 and Task 005, switch between `cognition-flow` and `capacity-vector`, and call the Pi tools from Task 008. The runbook must include exact local commands and a minimal happy-path transcript for one scenario in both variants; acceptance criterion is that a cold tester can reproduce the A/B loop without reading implementation code.

### Task 010: Build scoring worksheet and update experiment record

- **engine**: claude
- **profile**: balanced
- **thinking**: high
- **agent**: worker
- **depends**: 001, 003, 009
- **description**: Create `docs/experiments/2026-06-26-industrial-cognition-ab.scorecard.md` with the weighted metrics for player comprehension, Factorio-native feel, diagnostic usefulness, degradation clarity, fun/inspiration, implementation friction, and future extensibility. Use Task 001's scorecard fields, Task 003's scenario IDs, and Task 009's runbook flow, then update `docs/experiments/2026-06-26-industrial-cognition-ab.md` with links to the contract, runbook, and scorecard; acceptance criterion is that the experiment can be scored consistently after a demo run.

### Task 011: Validate public-safety, file ownership, and variant fairness

- **engine**: claude
- **profile**: deep
- **thinking**: high
- **agent**: reviewer
- **depends**: 002, 003, 004, 005, 006, 007, 008, 009, 010
- **description**: Review the full diff from Task 002, Task 003, Task 004, Task 005, Task 006, Task 007, Task 008, Task 009, and Task 010 for public-safety issues, secret leakage, accidental mutation paths, and unfair variant coupling. Specifically verify Task 008's `.pi/extensions/cogigator/index.ts` is variant-agnostic, Task 007's bridge serves the same schema for both variants, Task 006's common Factorio report files do not hard-code one variant's interpretation, Task 004 and Task 005 stay inside their variant modules, Task 003 fixtures are public-safe, and Task 009/Task 010 docs contain no secrets or sensitive infrastructure details; acceptance criterion is a written review note in `docs/experiments/2026-06-26-industrial-cognition-ab.review.md` with pass/fail findings.

### Task 012: Update public timeline and repository onboarding after the spike

- **engine**: codex
- **profile**: balanced
- **thinking**: medium
- **agent**: worker
- **depends**: 011
- **description**: Use Task 011's review output in `docs/experiments/2026-06-26-industrial-cognition-ab.review.md` as the safety gate before updating public documentation. After confirming Task 011 passed, update `docs/index.html`, `README.md`, and `docs/DEVELOPMENT_PROCESS.md` with a concise public-safe summary of the A/B substrate spike and links to the contract, runbook, scorecard, and review note; do not describe sensitive infrastructure beyond the already-public high-level context. The acceptance criterion is that GitHub Pages links resolve after deployment and the timeline captures the spike as a turning point rather than a raw changelog entry.

### Task 013: Final integration check and completion decision

- **engine**: pi
- **profile**: balanced
- **thinking**: medium
- **agent**: reviewer
- **depends**: 009, 010, 011, 012
- **description**: Run the documented local bridge/Pi/demo flow from Task 009 for at least two scenarios and both variants, touching the `bridge/` local server, `.pi/extensions/cogigator/index.ts`, `bridge/fixtures/*.json`, and `docs/experiments/2026-06-26-industrial-cognition-ab.scorecard.md`. Use Task 010's scorecard as the scoring target, Task 011's review note as the safety gate, and Task 012's updates to `docs/index.html`, `README.md`, and `docs/DEVELOPMENT_PROCESS.md` as the publication gate; the plan is complete when both variants are selectable through the same bridge/Pi path, the shared reports are comparable, no mutation path exists, docs are updated, and the experiment record states whether the next step is merge, synthesize, iterate, or park. ⚠ skipped (spike): live Kubernetes validation and real Factorio server deployment.
