# Cogigator Implementation Plan

This plan interprets `CONCEPT_BRIEF.md`, `INFRASTRUCTURE.md`, and `PI.md` as a
buildable Factorio 2.0/Space Age mod plus companion bridge and Pi control surface.

The distinctive direction is:

- Cogigator is not a magic chat box. It is a local, physical, bounded machine-mind.
- The in-game mod is authoritative for world state, permissions, and mutations.
- The bridge is a narrow transport and reasoning gateway, not a secret admin console.
- Pi is a developer/operator cockpit for safe observation and approvals.
- "AI capability" should become a Factorio production problem: compute, cooling,
  signal routing, power, footprint, and waste heat determine what Cogigator can do.

The plan intentionally preserves creative space. It defines architecture, constraints, and
MVP proof points without freezing every recipe, message field, or personality detail.

## Product Direction

Cogigator should feel like industrialized cognition installed into the factory. The player
does not merely place an "AI chest." They build a small datacenter cell: a cluster of
compute-producing machines, memory/signal infrastructure, cooling loops, and one or more
field stations that project cognition onto nearby production blocks.

The fantasy:

- A **Cogigator Datacenter** manufactures attention and analysis capacity.
- **Field Stations** spend that capacity to observe bounded worksites.
- Better datacenter infrastructure unlocks larger scans, deeper diagnostics, longer
  history, watches, faster responses, and more simultaneous stations.
- Multi-fluid compute machines become a real late-game puzzle: coolant, dielectric fluid,
  ion exchange, cryogenic fluid, waste heat, or other Space Age-adjacent flows can make
  "thinking" feel materially manufactured.
- The assistant is useful because it reads actual local game state, then explains and
  proposes within permissions the player can inspect.

This keeps the product grounded in Factorio. Cogigator's intelligence is a factory output,
not an external entitlement.

## Core Gameplay Loop

1. The player researches basic cognition technology.
2. The player builds a small datacenter cell that produces **compute capacity**.
3. The player places a **Cogigator Field Station** near a production block and assigns a
   rectangular worksite.
4. The station consumes power and allocated compute to scan the local area.
5. The mod produces deterministic site reports and first-order diagnostics.
6. The bridge and Pi extension expose those reports to the assistant.
7. The player asks questions such as "why is this block stalled?" or "can this area sustain
   45 packs/min?"
8. Cogigator answers with station, tick, and finding citations.
9. Later, Cogigator may propose inert build intents.
10. The player approves or rejects those intents through in-game UI and/or Pi commands.

Early play should feel like placing survey instruments. Midgame should feel like building a
small operations room. Lategame should feel like designing a compute plant whose layout,
fluids, energy profile, and cooling directly shape how much of the factory can be delegated
to machine cognition.

## Design Pillars

- **Locality is sacred:** stations see bounded worksites unless explicitly networked.
- **The mod is authority:** only Lua runtime validates actual game state and applies
  approved mutations.
- **Compute is physical:** cognition capacity comes from in-world infrastructure.
- **Observability before action:** read-only diagnostics must be useful before ghost
  placement or deconstruction exists.
- **Approval is explicit:** no mutation happens because an LLM sounded confident.
- **Kubernetes is first-class:** the plan fits the existing StatefulSet, RCON service,
  GitOps workflow, sealed-secret pattern, and monitoring stack.
- **Pi is a cockpit:** the Pi extension adapts bridge state into safe tools, status, and
  approval flows; it does not become the game-control runtime.

## In-Game Architecture

### Entities

Use three conceptual entity families.

#### Cogigator Field Station

The Field Station is the local observation point.

Responsibilities:

- Defines one rectangular worksite.
- Shows perimeter, online/offline/degraded status, and transport health.
- Consumes allocated compute and electric energy while scanning.
- Stores permission mode, scan interval, latest report metadata, and pending local intents.
- Provides in-game GUI for status, findings, and approvals.

Recommended behavior:

- Default worksite starts small, for example 32x32 tiles.
- Worksites are rectangular because Factorio factories, chunks, blueprints, and efficient
  `surface.find_entities_filtered { area = ... }` calls are rectangular.
- Station must sit inside or adjacent to its worksite.
- Larger worksites require higher station tier and more datacenter capacity.
- Overlapping worksites are allowed but visible and flagged.

#### Cogigator Datacenter Core

The Datacenter Core is the local coordinator and fiction anchor for manufactured cognition.

Responsibilities:

- Aggregates compute-producing buildings in a local network.
- Provides a force or surface-level capacity pool.
- Allocates capacity to stations.
- Exposes datacenter health: compute, cooling, memory, power, thermal stress, and degraded
  subsystems.
- Acts as the natural home for bridge/assistant configuration in the in-game GUI.

The Core can start as a simple powered entity in MVP and become richer once the observation
loop is proven.

#### Compute-Producing Machines

Compute machines make the datacenter into a Factorio system.

Candidate progression:

- **Relay Rack:** early, electric-only, low compute, high footprint.
- **Signal Processor:** mid-tier, consumes circuits or modules, produces more compute.
- **Memory Loom:** stores history capacity or watch slots.
- **Inference Engine:** high power draw, produces burst analysis capacity.
- **Thermal Exchanger:** handles waste heat or coolant loop pressure.
- **Cognitive Reactor / Cryogenic Matrix:** late-tier multi-fluid compute machine.

Do not over-specify exact recipes yet. The important implementation principle is that these
machines should expose enough state for the mod to compute capacity and degradation without
building a full hidden economy outside Factorio.

### Multi-Fluid Compute Machines

A custom assembly-machine-like prototype with multiple fluid inputs is in scope, especially
for late-game datacenter builds.

Design goals:

- Make routing and cooling a spatial puzzle, not just a recipe cost.
- Let the player improve Cogigator capability by improving industrial support systems.
- Support degraded operation: insufficient coolant reduces scan rate or analysis depth
  instead of simply making the entire assistant vanish.
- Avoid making the first MVP depend on complex fluid behavior.

Recommended staging:

- MVP: compute capacity is derived from a small number of simple powered entities.
- Post-MVP: add one fluid-cooled compute machine.
- Lategame: add multi-fluid high-tier compute machines with heat/coolant/waste constraints.

### Capacity Model

Represent manufactured cognition as a small set of abstract capacities rather than a large
resource spreadsheet.

Recommended initial capacities:

- **Scan capacity:** how much area/entity density can be sampled per interval.
- **Attention capacity:** how many stations/watches can be active.
- **Memory capacity:** how much history can be retained.
- **Planning capacity:** whether build intents and blueprint reasoning are enabled.

These can be internally calculated from datacenter entities and exposed to the player as
simple totals and bottlenecks. Exact formulas should stay tunable.

Examples:

- A small rack cluster supports one 32x32 read-only station.
- More scan capacity supports larger worksites or shorter intervals.
- More attention supports more watches.
- Memory banks unlock trend/history questions.
- Planning capacity unlocks proposal generation but not automatic construction.

## Data And State Model

### Mod-Owned State

The Factorio mod owns:

- station registry
- datacenter registry
- station-to-datacenter allocation
- worksite rectangles
- permission modes and force-level ceilings
- scan schedules and budgets
- latest site report summaries
- watch definitions
- pending and audited intents
- transport health

Store runtime state in `storage` and rebuild derived lookup tables on load/config changes.

### Site Reports

Site reports are generated by Lua and sent to the bridge. They should be deterministic,
bounded, and versioned, but not over-designed before implementation teaches what is useful.

Include, at minimum:

- schema/protocol version
- station id and datacenter id
- force, surface, tick, and worksite area
- station status and permission mode
- compute allocation and scan budget
- entity summaries
- representative machines with recipes/status/inventory/fluid/power state
- belt, inserter, pipe, power, logistic, train, resource, and ghost summaries where present
- first-order derived findings
- omitted-data/truncation markers

The mod should compute first-order diagnostics itself:

- machine input starvation
- output blocked
- no recipe
- missing fluid
- no power or low satisfaction
- inserter source/target blocked
- belt empty, saturated, or directionally suspicious
- pipe/fluid mismatch or empty required fluid
- construction ghost missing material
- resource patch below threshold
- station under-computed or thermally degraded

The assistant should explain, rank, and connect these findings. It should not invent raw
world facts from an unconstrained entity dump.

### Build Intents

Build intents are inert proposals until approved.

They should include enough information for human review and mod validation:

- stable intent id
- station id and report tick used
- affected area
- permission required
- summary and rationale
- proposed blueprint string or ghost/deconstruction operation
- material estimate
- risk level
- preconditions
- expiration
- validation summary

Avoid freezing all payload fields now. The invariant is more important: bridge validates
shape and scope, mod validates against current world state and permissions at apply time.

## Transport And Bridge Architecture

### Responsibility Split

```text
Pi TUI / coding agent
  -> project-local Cogigator Pi extension
      -> local or port-forwarded Cogigator bridge API
          -> Factorio mod via RCON, UDP, and/or file trace
              -> authoritative world state and approved mutations
```

The bridge owns:

- transport adapters
- report cache
- bridge API
- assistant/provider calls
- action intent validation before mod submission
- metrics and logs
- secret handling

The bridge does not own:

- raw game authority
- direct unapproved mutation policy
- RCON exposure beyond its private runtime boundary
- Pi session state

### Transport Strategy

Use a staged transport plan that respects the current infrastructure.

#### Stage 1: RCON/File Prototype

Start with RCON for local and cluster-adjacent development because the existing Kubernetes
deployment already exposes internal `factorio-rcon:27015`.

Use RCON only for narrow custom mod commands:

- list stations
- get latest compact report
- get pending actions
- submit approved/rejected action decision if needed
- bridge health/debug commands

Keep debug report output to `script-output/cogigator/` for fixtures and replay.

This proves the contract and report quality without immediately changing the critical
Factorio StatefulSet or launch flags.

#### Stage 2: In-Cluster Bridge Deployment

Run `cogigator-bridge` as a separate Deployment in the `factorio` namespace.

The bridge talks to:

- `factorio-rcon.factorio.svc.cluster.local:27015` for RCON
- the LLM provider via outbound network, if enabled
- Prometheus via `/metrics`, if configured

Local Pi connects by:

- `kubectl port-forward svc/cogigator-bridge ...`
- private Tailscale endpoint
- local bridge during development

This fits GitOps and avoids coupling bridge lifecycle to the game pod while the contract is
still changing.

#### Stage 3: UDP Sidecar For Rich Event Flow

Move to a sidecar or same-pod bridge when UDP/file streaming becomes valuable enough to
justify a StatefulSet change.

Use UDP when:

- continuous watch events matter
- report streaming outgrows RCON chunking
- low-latency bidirectional status matters
- the server can launch Factorio with `--enable-lua-udp`

The UDP protocol should use application-level reliability:

- protocol version
- message id
- kind
- station id
- tick
- chunk metadata and checksums for large reports
- acknowledgements for complete reports
- idempotent watch/action commands
- nonces and expirations for mutating requests

UDP loss must never mutate the world. Incomplete, stale, or permission-mismatched messages
are rejected by the mod.

### Bridge API

Expose a narrow HTTP API for Pi and any small external UI.

Recommended endpoints:

- `GET /health`
- `GET /version`
- `GET /stations`
- `GET /stations/{id}/snapshot`
- `POST /analyze`
- `GET /actions/pending`
- `POST /actions/propose`
- `POST /actions/{id}/approve`
- `POST /actions/{id}/reject`
- `GET /events/stream` later, via SSE or WebSocket
- `GET /metrics` later, Prometheus format

Responses should be compact, timestamped, versioned, and explicit about truncation.

## Pi Extension Workstream

Create a project-local Pi extension at:

```text
.pi/extensions/cogigator/index.ts
```

The extension is a control surface and tool adapter. It must not contain Factorio/RCON
control logic directly and must not store secrets.

### Initial Commands

- `/cogigator-connect [endpoint]`
- `/cogigator-disconnect`
- `/cogigator-status`
- `/cogigator-snapshot`
- `/cogigator-actions`
- `/cogigator-approve <action-id>`
- `/cogigator-reject <action-id>`
- `/cogigator-config`

### Initial Tools

- `cogigator_status`: read bridge/server health and version.
- `cogigator_snapshot`: read a bounded station/datacenter snapshot.
- `cogigator_analyze`: ask the bridge for deterministic diagnostics/context packaging.
- `cogigator_pending_actions`: list inert pending intents.
- `cogigator_propose_action`: create an inert proposal, not a mutation.

Approval should preferably be command/UI driven. If approval exists as an LLM-callable tool,
it must require `ctx.ui.confirm()` and fail closed in non-UI modes.

### UI Behavior

- Footer status: disconnected, connected, degraded, or error.
- Widget: pending actions, latest alert, or bridge warning.
- Confirmation dialog for every approval.
- Compact renderers for snapshot/action results.
- Event stream or polling only after read-only tools are stable.

### Resilience Rules

- Store only non-secret endpoint config in `.pi/cogigator.json`, and only after project
  trust.
- Respect `COGIGATOR_BRIDGE_URL` as an environment override.
- Start long-lived SSE/WebSocket/port-forward processes only during `session_start` or an
  explicit command.
- Clean up all child processes and streams on `session_shutdown`.
- Use short request timeouts and clear errors.
- Keep tool output compact; put larger structured data in `details` only when useful.
- Re-query pending actions from the bridge rather than trusting only Pi session memory.

## Kubernetes Deployment Implications

The current production shape matters:

- Factorio is a single StatefulSet pod in namespace `factorio`.
- Image is currently `factoriotools/factorio:2.0.77-rootless`.
- It uses `hostNetwork: true`.
- Persistent data is mounted at `/factorio`.
- RCON is internal via `factorio-rcon` ClusterIP on TCP 27015.
- Game traffic is UDP 34197 on the node network.
- Deployment is GitOps-managed by ArgoCD from the `factorio-server` repo.
- Secrets are sealed; do not put credentials in docs or committed config.
- Monitoring/logging already exists via Prometheus/Grafana/Loki/Promtail.

Recommended deployment path:

1. Develop locally against a modded Factorio instance and/or RCON port-forward.
2. Add the Cogigator mod to the Factorio mod list through the `factorio-server` repo.
3. Add a separate `cogigator-bridge` Deployment in the `factorio` namespace.
4. Mount provider/RCON credentials from Kubernetes Secrets created through the existing
   Sealed Secrets workflow.
5. Expose bridge only privately: port-forward, cluster service, or Tailscale/private path.
6. Add `/health` and `/metrics`; log to stdout/stderr.
7. Only later modify the Factorio StatefulSet for a sidecar or `--enable-lua-udp`.

Operational constraints:

- Do not expose RCON publicly.
- Do not assume public HTTP ingress is acceptable for control operations.
- Prefer GitOps changes over manual `kubectl apply`.
- Treat live cluster state as requiring re-verification when kube access is available.
- Keep bridge resource requests conservative so it does not pressure the Factorio server.
- Avoid restarts of the critical StatefulSet until a change is clearly worth it.

Suggested bridge metrics:

- `cogigator_bridge_health`
- `cogigator_rcon_requests_total`
- `cogigator_rcon_errors_total`
- `cogigator_snapshot_duration_seconds`
- `cogigator_reports_truncated_total`
- `cogigator_llm_requests_total`
- `cogigator_llm_request_duration_seconds`
- `cogigator_actions_proposed_total`
- `cogigator_actions_approved_total`
- `cogigator_actions_rejected_total`
- `cogigator_mod_protocol_version`

## MVP Phases

### Phase 0: Contract And Mod Skeleton

Tasks:

- Create Factorio mod scaffold: `info.json`, `settings.lua`, `data.lua`, `control.lua`,
  `prototypes/`, `scripts/`, and `locale/`.
- Add bridge scaffold with RCON adapter, fake assistant, typed models, and report fixtures.
- Define minimal typed models for station list, site report, bridge response, and action
  intent.
- Add file-output debug reports for replay.
- Add linting/formatting appropriate to Lua and bridge code.

Exit criteria:

- The mod loads in Factorio 2.0.
- The bridge starts without a real LLM key.
- Fixtures validate against the minimal contract.
- No world mutation path exists.

### Phase 1: Field Station And Worksite

Tasks:

- Add Field Station item, recipe, entity, technology, map icon, and GUI.
- Track station lifecycle in `storage`.
- Add Survey Lens selection tool for rectangular worksite assignment.
- Render worksite perimeter and station state.
- Add power consumption and offline/degraded behavior.
- Add force-level permission ceiling and station-level mode.

Exit criteria:

- A player can research, craft, place, configure, and remove a Field Station.
- The station visibly owns a bounded worksite.
- Permission mode is visible and conservative by default.

### Phase 2: Basic Datacenter Capacity

Tasks:

- Add Datacenter Core and one simple compute-producing entity.
- Calculate available scan/attention capacity from nearby or linked datacenter entities.
- Allocate capacity to Field Stations.
- Show datacenter bottleneck status in station/core GUI.
- Make insufficient capacity degrade scan interval, worksite size, or report depth.

Exit criteria:

- At least one station requires manufactured compute capacity to operate beyond a minimal
  fallback mode.
- The player can see why a station is underpowered, under-computed, or offline.

### Phase 3: Deterministic Site Reports

Tasks:

- Implement scheduled scanning spread across ticks.
- Summarize entities by type, recipe, status, inventory, fluidbox, belt direction, ghost
  state, power state, and relevant logistics.
- Add first-order derived findings in Lua.
- Enforce scan budgets tied to datacenter capacity.
- Record omitted-data markers.
- Write debug reports to `script-output/cogigator/reports/`.
- Add local commands/RCON commands for latest report summary.

Exit criteria:

- A real production cell yields a compact report explaining obvious local conditions
  without an LLM.
- Dense worksites degrade by reporting truncation/omissions rather than hurting UPS.

### Phase 4: Bridge And Read-Only Pi MVP

Tasks:

- Implement bridge RCON adapter for list-stations and latest-report.
- Add bridge `/health`, `/version`, `/stations`, and snapshot endpoints.
- Add project-local Pi extension with status and snapshot tools.
- Add `/cogigator-connect`, `/cogigator-status`, and `/cogigator-snapshot`.
- Require assistant answers to cite station id, tick, and report findings.
- Add test scenarios: starved assembler, blocked output, low power, missing fluid, missing
  construction materials, low ore, and under-computed station.

Exit criteria:

- Pi can connect to a local or port-forwarded bridge.
- The assistant can answer "why is this area stalled?" from a bounded station report.
- Answers cite concrete report data.
- No build, deconstruction, or direct mutation capability exists.

This is the first true MVP.

### Phase 5: Watches, Alerts, And History

Tasks:

- Add watch definitions per station: condition, threshold, cooldown, enabled flag.
- Evaluate simple watches in Lua from report data.
- Add bridge endpoints and Pi UI for watches/events.
- Add Memory capacity as a limit on retained history and number of watches.
- Show recent alerts in station GUI and Pi widget.
- Avoid noisy auto-turns in Pi; batch and summarize.

Exit criteria:

- The player can ask Cogigator to watch an outpost or production block and get a concise
  alert when a local threshold is crossed.
- History questions are limited by visible datacenter memory capacity.

### Phase 6: Planner Mode And Intent Ledger

Tasks:

- Add Planner permission mode and planning-capacity requirement.
- Let the assistant/bridge submit inert build intents.
- Validate intents in the bridge for schema, scope, risk, and permission.
- Validate intents again in the mod against station area, current surface, force,
  collisions, current report freshness, and permission mode.
- Add in-game intent ledger with reason, area, risk, material estimate, and expiration.
- Add Pi pending-action widget and approve/reject commands.

Exit criteria:

- Cogigator can propose a local layout change.
- The world remains unchanged until the player approves a ledger entry.
- Rejected, expired, and failed-precondition actions are visible and auditable.

### Phase 7: Ghost Placement And Blueprint Export

Tasks:

- On approval, place construction ghosts only inside the station worksite.
- Support blueprint-string export as a safer alternative.
- Reject stale intents when the world changed since the report tick.
- Deduplicate overlapping ghosts.
- Summarize material availability.
- Record audit entries for every approved mutation.

Exit criteria:

- A player can approve a local Cogigator proposal and see ghosts appear, or export a
  blueprint instead.
- All mutations are bounded, permissioned, and auditable.

### Phase 8: Rich Datacenter Mechanics

Tasks:

- Add fluid-cooled compute entities.
- Add at least one multi-fluid high-tier compute machine if prototype constraints allow.
- Add thermal/cooling degradation effects.
- Add quality/tier/module interactions where they produce interesting build tradeoffs.
- Tune capacity formulas for scan size, watch count, history depth, and planner access.
- Keep exact recipes flexible until playtesting shows which bottlenecks are fun.

Exit criteria:

- Building a better datacenter materially changes Cogigator capability.
- Cooling and fluid routing are interesting but not mandatory for the read-only baseline.

### Phase 9: Kubernetes Hardening

Tasks:

- Containerize the bridge.
- Add Kubernetes manifests in the appropriate GitOps repo.
- Add sealed-secret references for provider and RCON credentials.
- Add readiness/liveness checks for bridge health, Factorio reachability, and schema
  compatibility.
- Add resource requests/limits.
- Add metrics and dashboards if the bridge becomes always-on.
- Document local, port-forward, in-cluster Deployment, and optional sidecar/UDP modes.

Exit criteria:

- Cogigator works against the headless Kubernetes server using structured state only.
- The deployment does not require public RCON or public control ingress.
- ArgoCD-managed changes are reproducible.

### Phase 10: UDP Sidecar And Continuous Events

Tasks:

- Enable Factorio Lua UDP only after the RCON bridge path is stable.
- Add sidecar or same-pod bridge design to the Factorio StatefulSet.
- Implement chunked, acknowledged UDP report/event exchange.
- Add event stream from bridge to Pi.
- Keep RCON as administrative fallback.

Exit criteria:

- Cogigator supports lower-latency watches and richer report flow without relying on RCON
  chunking.
- UDP transport failures degrade safely and never cause mutation.

## Permission Model

Use a force-wide ceiling plus per-station mode.

Modes:

1. **Silent Monitor:** local scanning only, no external bridge payloads.
2. **Read-Only Advisor:** reports may leave the game; no proposals.
3. **Planner:** assistant may create inert intents for review.
4. **Construction Draftsman:** approved intents may place construction ghosts.
5. **Demolition Draftsman:** approved intents may mark deconstruction.
6. **Debug Executor:** admin-only, explicit test mode, never default.

Defaults:

- New stations start conservatively.
- Force ceiling requires admin/player permission.
- All mutation approvals include station, area, risk, summary, and payload preview.
- Non-interactive Pi or bridge modes fail closed for approval.

## Testing Strategy

### Mod Tests And Fixtures

- Use deterministic report fixtures from known saves or scripted scenarios.
- Test station lifecycle, worksite assignment, capacity allocation, scan budgeting, and
  permission transitions.
- Test derived findings for common failures.
- Test dense areas and truncation behavior.

### Bridge Tests

- Validate schema versions and truncation.
- Test RCON adapter against mocked responses first.
- Replay file-output reports.
- Test action validation and stale/precondition rejection.
- Test provider-disabled mode.

### Pi Extension Tests

- Run against a stub bridge.
- Verify status/snapshot commands.
- Verify compact tool output and truncation notices.
- Verify approval fails closed without UI.
- Verify session cleanup for event streams or port-forward helpers.

### Integration Tests

- Local Factorio read-only loop.
- Kubernetes RCON port-forward loop.
- In-cluster bridge loop.
- Later: sidecar UDP loop.

## Major Risks And Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Datacenter mechanics delay the useful assistant | High | Keep Phase 2 capacity simple; prove read-only value before rich fluids |
| Compute abstraction feels fake | Medium | Tie visible capability changes to real machines, power, footprint, cooling, and bottlenecks |
| Multi-fluid machines are prototype-heavy | Medium | Defer to Phase 8; start with simple powered compute entities |
| Zone scanning hurts UPS | High | Rectangles, scan intervals, tick spreading, capacity budgets, omitted-data reporting |
| Reports are too verbose for LLM use | High | Lua-derived diagnostics, compact summaries, explicit truncation |
| Assistant gives wrong but confident advice | High | Require station/tick/finding citations and preserve deterministic diagnostics |
| RCON-first prototype leaks into final design | Medium | Keep bridge transport abstraction; treat RCON as adapter, not product model |
| UDP flag/sidecar change disrupts server | Medium | Defer UDP until stable; begin with separate bridge Deployment |
| Kubernetes secrets leak | High | Use Sealed Secrets; never commit or print secret values |
| Bridge resource use impacts Factorio | High | Separate Deployment first, conservative limits, metrics, no high-frequency polling |
| Pi extension becomes a hidden authority | High | Pi talks only to bridge; bridge and mod revalidate everything |
| Multiplayer approval authority is unclear | Medium | Define admin/force permission rules before Planner mode |
| Existing mods conflict or overlap | Medium | Focus on situated diagnosis and approvals; complement Factory Planner/Rate Calculator |

## Open Questions

- What is the best Factorio prototype for Field Station status without misleading players
  into thinking it is a normal assembler?
- Should datacenter linkage be radius-based, circuit-network-like, explicit wired links, or
  force-wide after research?
- Which capacities should be visible as first-class resources versus hidden implementation
  budgets?
- What exact failure states should under-computation produce: slower scan, smaller area,
  less detail, fewer watches, or all of these?
- How strict should worksite sizes be: free rectangles, tier-snapped rectangles, or
  blueprint-like block sizes?
- How much history belongs in the mod versus the bridge?
- Which watch conditions are useful enough to implement in Lua first?
- Should blueprint proposals be assistant-authored, template-based, or constrained to
  modifying player-provided blueprints?
- What approval roles make sense in multiplayer?
- Should the default personality be field engineer, machine oracle, operations console, or
  configurable per datacenter?
- How much should Space Age planets affect cognition recipes and fluid/cooling chains?
- When is UDP worth the StatefulSet/launch-flag cost compared with RCON plus polling?

## Recommended First Milestone

The first milestone should stop at Phase 4.

It proves:

- A player can build a Field Station and minimal datacenter capacity.
- The station observes a visible bounded worksite.
- The mod produces deterministic, budgeted reports from actual game state.
- The bridge retrieves those reports through the current infrastructure-compatible path.
- Pi exposes safe status/snapshot tools.
- The assistant answers local diagnostic questions with station/tick citations.
- There is no mutation capability.

After that, the project can choose whether the next most valuable push is richer gameplay
capacity, watches/history, planner intents, or Kubernetes hardening. The architecture keeps
those paths independent enough that one can advance without forcing all the others.
