# Probe: Cognition Network Human Comprehension

- Date: 2026-06-27
- Status: ready
- Related synthesis: [Cognition Network Synthesis](2026-06-27-industrial-cognition-synthesis.md)
- Related scorecard: [Industrial Cognition A/B scorecard](2026-06-26-industrial-cognition-ab.scorecard.md)

## Purpose

Check whether the **Cognition Network** wording makes a human understand what to build or change next without needing to read implementation code or raw JSON.

This is not a live-server validation. It is a small player-facing comprehension probe using the current local bridge/Pi output and the local Factorio entity shell.

## Setup

1. Start the local bridge if testing Pi output:

   ```bash
   PORT=8787 node bridge/server.mjs
   ```

2. In Pi, run one degraded/truncated snapshot:

   ```text
   /cogigator-snapshot under-computed capacity-vector
   /cogigator-snapshot dense-cell-truncated capacity-vector
   /cogigator-snapshot dense-cell-truncated cognition-flow
   ```

3. Optionally open the local Factorio test save and show the available entities:
   - Cogigator Field Station
   - Cognition Processor
   - Memory Bank
   - Planning Relay

## Probe script

Show the participant one snapshot output. Do not explain the system first.

Ask:

> Based only on this output, what would you build or change next in the factory?

Then ask:

> What part of the output told you that?

Then ask:

> Does this feel like a Factorio infrastructure problem, or like an abstract status panel?

## Scoring

Use 1-5 scores.

| Metric | 5 | 3 | 1 |
|---|---|---|---|
| Next-action clarity | Names a concrete build/change: add Field Stations, Cognition Processors, Memory Banks, Planning Relay, split cell, or reduce watched sites | Identifies general issue but not exact action | Cannot say what to build/change |
| Evidence traceability | Points to a specific bottleneck/effect line | Points to general degraded status only | Cannot identify evidence |
| Factorio-native feel | Describes it as infrastructure/logistics/capacity | Mixed: partly game-like, partly dashboard | Feels detached from Factorio |
| Trust/readability | Understands truncation/degradation as honest limitation | Understands some of it | Thinks output is broken or misleading |

## Result capture

| Field | Response |
|---|---|
| Participant / initials |  |
| Scenario shown |  |
| Variant shown |  |
| Next action answer |  |
| Evidence they cited |  |
| Factorio-native reaction |  |
| Confusing wording |  |
| Next-action clarity score |  |
| Evidence traceability score |  |
| Factorio-native feel score |  |
| Trust/readability score |  |
| Overall pass? | yes / no / iterate |

## Pass condition

The synthesis passes this probe if the participant can name a concrete next build/change and cite the relevant bottleneck/effect line without additional explanation.

## Follow-up decisions

- If pass: keep Cognition Network wording and begin designing live read-only snapshot extraction.
- If partial: revise entity/capacity wording and rerun the probe.
- If fail: revisit whether explicit capacities should be exposed differently in the Pi output.

## Safety notes

No credentials, server details, live cluster output, or mutation behavior are involved. This probe uses local fixtures and/or a local test save only.
