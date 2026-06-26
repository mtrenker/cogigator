# Cogigator — Implementation Plan

> A Factorio 2.0 / Space Age mod plus companion system that places "thinking" structures in
> the factory. Each gives an external AI assistant a **bounded, physical** view of a
> production cell, the ability to diagnose and explain from real game state, and — only with
> explicit approval — to prepare construction.
>
> Sources of truth: [`CONCEPT_BRIEF.md`](./CONCEPT_BRIEF.md),
> [`INFRASTRUCTURE.md`](./INFRASTRUCTURE.md), [`PI.md`](./PI.md). This plan turns them into a
> phased, opinionated build. No implementation code here — this is the engineering direction.
>
> This is a **distinct** interpretation, not a merge of `PLAN.gpt-5.5.md`. Where that plan is
> contract-first and UDP-sidecar-primary, this plan is **RCON-first by infrastructure
> necessity**, **Pi-native** (the assistant *is* Pi, not a re-implemented LLM loop), and
> builds its identity around one big idea the brief now foregrounds: **cognition is a thing
> your factory manufactures.**

---

## 0. What changed in this revision

Three new inputs reshaped the plan:

1. **The server already exists** (`INFRASTRUCTURE.md`). It's Factorio `2.0.77` + Space Age, a
   single critical StatefulSet with `hostNetwork`, no `--enable-lua-udp`, RCON exposed only as
   an in-cluster ClusterIP, GitOps via ArgoCD, sealed secrets, a Prometheus/Loki stack, tight
   CPU/memory budgets, and a roster of mods including `flib`/`stdlib2`. **Consequence:**
   UDP-first is now the *expensive* path (it mutates the critical pod's launch and demands a
   sidecar), and RCON-via-separate-Deployment is the cheap, GitOps-clean path. My earlier
   "RCON now, grow into UDP" ordering is now the load-bearing decision, not a convenience.

2. **The assistant is Pi** (`PI.md`). Pi is a terminal coding-agent harness with an extension
   system. The right shape is a **three-layer split**: a Pi extension (read-only model tools +
   approval UI, *no* game-control logic) → a narrow versioned **bridge** API → the **mod** as
   sole authority. I am *deleting* the idea that the bridge re-implements its own agent loop
   for the operator path; Pi already is that loop. The bridge keeps a small, optional embedded
   assistant only for the in-game player chat surface (deferred).

3. **Industrialized cognition** (`CONCEPT_BRIEF.md` §"Emerging gameplay direction"). The
   datacenter is not one magic box; it is a **manufactured compute facility**. This becomes
   the spine of the design, not flavor. See §4.

---

## 1. Product fantasy & the one-paragraph pitch

A Cogigator is a half-sentient industrial co-processor you wire into your base. It is not
omniscient: **it sees only what you physically plug it into, and it can only think as hard as
your factory can manufacture thought.** The personality is a terse, slightly eccentric factory
oracle — competent, blunt, occasionally ominous ("Cell 3 has been starving for nine minutes. I
assume this is intentional."). Two scarcities define it and make it a Factorio problem rather
than a chat overlay:

- **Sightline** — *where* it can look. Bought by placing Cogigator Cores in production cells.
- **Cognition** — *how hard* it can think. **Manufactured** by a compute facility you build,
  power, cool, and feed.

You always remain the hand. The Cogigator is only ever the eyes, the voice, and — once you let
it — the draftsman whose proposals you approve.

---

## 2. System architecture (the three layers)

```
┌─ Operator workstation ────────────────┐      ┌─ factorio namespace (K8s) ─────────────────┐
│  Pi TUI                               │      │                                            │
│   └─ .pi/extensions/cogigator         │      │  cogigator-bridge  (new Deployment)        │
│        • read-only model tools        │ HTTP │   • owns RCON conn to factorio-rcon:27015  │
│        • /cogigator-* commands + UI   │◀────▶│   • builds/serves bounded snapshots        │
│        • approval flow, status widget │ /SSE │   • deterministic diagnostics              │
│        • talks ONLY to the bridge     │      │   • validates + holds action intents       │
└───────────────────────────────────────┘      │   • Prometheus /metrics, stdout logs       │
                                                │   • secrets via SealedSecrets              │
   (in-game players, all 5)                     │            │ RCON (TCP 27015, in-cluster)  │
        in-game Cogigator GUI ──────────────────┼────────────┤                               │
        status • ask • approve                  │  factorio StatefulSet (existing, critical) │
                                                │   └─ Cogigator MOD (Lua)                   │
                                                │        • SOLE world authority              │
                                                │        • zone scan + Cognition sim         │
                                                │        • permission + action ledger        │
                                                └────────────────────────────────────────────┘
```

**Layer responsibilities — and the rule that makes the system safe:**

| Layer | Owns | Must never |
|---|---|---|
| **Mod (Lua)** | Prototypes, zone scanning, the **Cognition economy** simulation, deterministic diagnostics, permission state, the in-game approval ledger, and *every* world mutation. | Be bypassed. It re-validates every intent at apply time. It is the only thing that touches `LuaSurface`. |
| **Bridge (in-cluster service)** | The single RCON connection, snapshot assembly/caching, action-intent storage + a second independent permission check, the narrow versioned HTTP/SSE API, metrics. | Expose RCON publicly; hold authority; emit a mutating call above the active tier. |
| **Pi extension** | Model-callable *read-only* tools, the approval *command/UI* flow, compact status/widgets, resilient connection management. | Contain Factorio/RCON/LLM game-control logic. It is a control surface and tool adapter — **not** a security boundary (PI.md). |

**Why two "brains" can coexist.** The operator drives Pi (Pi brings its own model). In-game
players get a simpler embedded-assistant chat *later*, served by the bridge. Both are gated by
the *same* mod-enforced permissions, the *same* action ledger, and the *same* Cognition
budget. Authority never lives in a model; it lives in the mod.

### 2.1 Transport decision — settled by the infrastructure

| Option | Verdict | Reasoning under the real cluster |
|---|---|---|
| **RCON via a separate `cogigator-bridge` Deployment** | **PRIMARY (MVP + prod)** | Reaches `factorio-rcon.factorio.svc.cluster.local:27015` with **zero change to the critical StatefulSet**. Pure-additive GitOps. Independently restartable. This is the infra doc's Option A. |
| **File output to `script-output/`** | **DEBUG/REPLAY only** | The mod always also writes the latest snapshot as a JSON artifact. Near-zero cost, priceless for fixtures, tests, and bug reports. Reading it back into the bridge needs PVC sharing, so it stays a one-way trace, not a channel. |
| **UDP (`helpers.send_udp`) + sidecar** | **DEFERRED, justify-before-building** | Genuinely better for push/streaming watches, *but* costs a launch-flag change (`--enable-lua-udp`) on the critical pod **and** a same-pod sidecar (infra Option B) that couples failure domains. Only pursue once watches prove their value and RCON polling is demonstrably the bottleneck. |
| **In-mod HTTP/sockets** | **REJECTED** | Control-stage Lua cannot open sockets. |

RCON is request/response and chunk-limited. Both are fine for the MVP loop *because* the mod
derives diagnostics and bounds snapshots — we move *signals*, not entity dumps. Watches (the
one push-shaped feature) start as **bridge-side polling with backoff**; UDP is the eventual,
opt-in upgrade, not a prerequisite.

---

## 3. In-game objects & progression

The system is deliberately **two devices**, mirroring the two scarcities:

### 3.1 The Cogigator Core — *sightline* (the eyes)
- A powered custom entity placed inside a production cell. Recommend an
  `assembling-machine`-class prototype (free power draw, status states, GUI hook) running an
  inert "observe" recipe, **or** a simpler powered entity + custom GUI. Resolve in Phase 1
  against which gives honest status without misleading recipe/inventory behavior.
- Defines a **rectangular worksite** anchored to the Core (rectangles align with production
  blocks, blueprints, chunk math, and `find_entities_filtered{area=...}`). A toggleable
  overlay renders the perimeter and a `live / stale / offline / overloaded` status tint.
- Idle draw is small; **active analysis spikes power** — thinking visibly costs energy.
- A Core with no Cognition feeding it is a *dumb status panel*: it can show local numbers but
  cannot answer, plan, or watch. This is the hook into the second device.

### 3.2 The Datacenter — *cognition* (the brain), §4
A **collection** of compute machines that manufacture Cognition for the force. Detailed below.

### 3.3 Progression (a new tech branch, riding Space Age)
1. **Cognitive Substrate** — unlocks the Core + a tier-1 compute machine. Read-only advisor.
2. **Thermal Compute** — unlocks coolant-fed compute and Memory Banks (bigger context).
3. **Inference Matrices** — the multi-fluid high-tier machine; larger zones, faster cadence.
4. **Drafting Authority** — unlocks Planner/Draftsman tiers (proposals, ghost placement).
5. *(Space Age synergy, optional)* compute machines accept **quality** tiers for higher
   Cognition yield, giving the quality system a reason to exist for the brain.

Names and recipes here are **illustrative, not final** — the brief explicitly asks us not to
prescribe the chain. The *shape* (sightline cheap-ish, cognition a real production problem) is
the commitment.

---

## 4. Industrialized cognition — the distinctive core

This is what makes Cogigator memorable. **AI capability is a manufactured throughput problem.**

### 4.1 The two resources
- **Sightline** is spatial and cheap-ish: place Cores.
- **Cognition** is a manufactured **flow** (units/min) plus a **buffer** (a store). It is
  produced by the datacenter and consumed by analysis. Model it like a second energy network
  scoped to the force (simplest), with a spicier physical-cartridge variant as an open fork
  (§10). A Core draws Cognition to do anything beyond showing raw local numbers.

### 4.2 The compute machines (illustrative roles, not locked recipes)
| Machine | Role | The Factorio puzzle it creates |
|---|---|---|
| **Thinking Rack** (T1) | electricity + one coolant → Cognition | Entry compute; cooling is a single loop. |
| **Inference Matrix** (T3) | **multi-fluid** (e.g. coolant + a dielectric/secondary loop) + heavy power → high Cognition, emits **hot coolant / waste heat** | The headline machine the brief invites: several fluid lines make **cooling and fluid routing the puzzle**. Waste heat must be radiated or recycled or the matrix throttles. |
| **Coolant Plant / Heat Exchanger** | regenerates spent/hot coolant | Closes the loop; turns cooling into infrastructure, not a free input. |
| **Memory Bank** | buffers Cognition; extends retained **history/context** | Literally the context window as a built structure — more banks → deeper history, more tracked zones, longer plans. |
| **Signal Processor / Interconnect** | links Cores to the Cognition network; sets per-Core priority | How sightline draws on the brain; lets you starve or favor specific cells. |

The delicious mapping: **cooling lets you run thought harder; memory lets you think about
more at once; waste heat punishes naive overclocking.** AI concepts become belts and fluids.

### 4.3 How Cognition gates the assistant (the part that ties it all together)
The mod simulates Cognition deterministically and exposes *available throughput* and *buffer*
to the bridge. The bridge maps that to real capability:

| In-game Cognition state | Assistant behavior the bridge enforces |
|---|---|
| Throughput | snapshot cadence/freshness; how many zones can be **active** at once; how many concurrent watches. |
| Buffer (Memory Banks) | analysis depth and retained history; whether a *deep* plan request is affordable. |
| Per-request "spend" | a status glance is cheap; a layout-planning request is expensive and **drains the buffer** — visibly, in-game. |
| Starved (buffer empty, low flow) | responses queue, degrade to deterministic-only answers, or refuse with "insufficient Cognition" — surfaced on the Core overlay as `overloaded`. |

**The alignment that nobody else has:** in-game manufactured Cognition can be wired to *govern
real LLM spend*. Low Cognition → the bridge serves cached/deterministic answers or a cheap
model tier; high Cognition → it permits a deeper model and larger context. The factory you
build to "afford thinking" is, under the hood, your token budget. This is both a great game
mechanic and a genuine cost-control mechanism for a hosted, multiplayer deployment.

---

## 5. The gameplay loop

1. **Research & place a Core** in a production cell. See exactly what it can see (overlay).
2. **Build a datacenter** to manufacture Cognition — power it, cool it, route its fluids,
   buffer it with Memory Banks. Now the Core can actually *think*.
3. **Ask, grounded.** "Why is this science block stalling?" The assistant answers from a real
   snapshot of that zone, citing the actual bottleneck — spending Cognition to do so.
4. **Watch.** "Tell me when this outpost runs low on ore." A watch consumes a trickle of
   Cognition and alerts you when a local threshold trips.
5. **Propose & approve.** With Drafting Authority enabled, the assistant submits an **inert
   build intent** (ghosts/blueprint + material cost + reason). You review the diff in the
   in-game **approval ledger** and commit or reject. Nothing mutates without your click.
6. **Scale by manufacturing more brain and placing more eyes.** Bigger zones, faster cadence,
   more simultaneous Cogigators — each a deliberate production investment, not a free unlock.

The loop is a genuine Factorio optimization problem: balance sightline against cognition,
cooling against heat, depth-of-thought against throughput.

---

## 6. Data model (the stable contract)

The **snapshot** is the unit of observation: a bounded, versioned JSON document per Core,
produced by the mod, served by the bridge, consumed by Pi. Keep fields *open* per the brief —
the commitments are the **principles**, not an exhaustive schema. The bridge API surface
itself follows the contract in `PI.md` (`/health`, `/snapshot`, `/analyze`, `/actions/*`,
optional `/events/stream`, `/metrics`); this plan does not re-specify those fields.

A snapshot carries, at minimum: identity (`core_id`, `tick`, `surface`, `bounds`,
`schema_version`); a **Cognition block** (available throughput, buffer, this Core's draw
priority, overloaded flag); power satisfaction; scoped entity/production/inventory/logistics
summaries (incl. **fluids**, given the compute machines lean on them); **derived findings**
(starved / backed-up / no-power / no-recipe / missing-fluid / overheating / ghost-missing-item
/ patch-below-threshold); pending ghosts; and an explicit `omitted`/`truncated` marker.

Principles:
- **Derive before sending.** The mod computes diagnostics so the model *selects* an
  explanation rather than inventing one. This is the single biggest anti-hallucination lever.
- **Bounded & honest.** Hard entity-count caps; over-cap Cores report *partial coverage* and
  flag it (this is the in-fiction "overloaded" / Cognition-starved state), never blow context.
- **Diff-friendly & versioned.** `tick`-stamped, small enough to compare over time;
  `schema_version` lets mod and bridge evolve independently.

---

## 7. Permissions & safety (defense in depth)

Per-Core mode, never above a **force-wide ceiling**. Enforced in **two independent places** —
the mod (authoritative; owns the surface) and the bridge (refuses to even emit a mutating call
above the active tier). The Pi extension is *not* a boundary.

1. **Silent Monitor** — local GUI only; emits no external payload.
2. **Read-Only Advisor** *(default once connected)* — snapshots + answers; no proposals.
3. **Planner** — may return blueprint strings / inert build intents for review.
4. **Construction Draftsman** — approved intents may place **ghosts** (normal construction).
5. **Demolition Draftsman** — approved intents may mark deconstruction.
6. **Debug Executor** — admin-only, off by default, visibly flagged; direct ops for testing.

Every mutating action flows through the **in-game approval ledger**: a reviewable diff with
affected tiles, material estimate, reason, and expiry. The mod re-validates at apply time
(area, surface, force, collision, staleness vs. snapshot tick) and writes an **audit entry**.
Intents expire; stale intents (world changed since the snapshot tick) are rejected. In
non-interactive / non-UI contexts the system **fails closed**.

---

## 8. MVP phases

Each phase ends with a **demonstrable** capability. **Phases 1–4 are the MVP.** Throughout,
Factorio UPS is a first-class constraint (the pod has hard CPU/memory limits and shares a busy
cluster) and **no permanent cluster change is made until the contract is proven** (infra doc's
staged direction: local prototype → in-cluster bridge → optional richer transport).

### Phase 0 — Scaffolding & contract
- Mod skeleton (`info.json` pinned to `2.0.x`/Space Age, `data.lua`, `control.lua`,
  `settings.lua`, `prototypes/`, `scripts/`, `locale/`); reuse `flib`/`stdlib2` already on the
  server. Bridge scaffold (language: see §10) with an RCON client and a **fake assistant**.
  Pi extension skeleton with a no-op `/cogigator-status`. Schemas for snapshot + action-intent
  with a sample fixture corpus. Lua + bridge lint in CI.
- **Dev transport = RCON via `kubectl port-forward svc/factorio-rcon 27015:27015`** (infra
  Option C). No cluster changes yet.
- **Exit:** mod loads; bridge answers `/cogigator ping` over port-forwarded RCON; fixtures
  validate.

### Phase 1 — The Core & its worksite (no AI, no cognition cost)
- Core item/recipe/entity/tech; lifecycle tracked in `storage`. Rectangular worksite via a
  selection tool; perimeter overlay with status tints; power draw + idle/active states; Core
  GUI shell (bounds, entity count, permission tier, transport health).
- **Exit:** player researches, crafts, places, configures, and removes a Core and sees its
  bounded coverage.

### Phase 2 — Deterministic snapshots & diagnostics
- Interval scanning **spread across ticks** with a per-Core scan budget; entity/production/
  inventory/**fluid**/logistics summaries; first-order derived findings in Lua; over-cap →
  partial-coverage flag. Emit to `script-output/cogigator/` (debug trace) **and** serve the
  latest via an RCON command (chunked). Bridge parses into a clean internal model.
- **Exit:** for a real, deliberately-broken cell, the bridge prints a correct human-readable
  diagnosis **with no LLM involved**, and dense zones degrade by *omitting*, not by stalling.

### Phase 3 — The Cognition economy (the differentiator, early)
- Tier-1 compute machine + the Cognition network sim (throughput + buffer, deterministic);
  Memory Bank (buffer/history); a Core consumes Cognition to produce a *servable* (non-raw)
  snapshot. Surface Cognition state in the Core GUI and snapshot. Bridge reads Cognition and
  enforces simple gating (cadence + refuse-when-starved).
- **Exit:** a player who hasn't built/cooled enough compute gets visibly throttled answers;
  building more datacenter measurably improves freshness/depth. Cognition is *felt*.

### Phase 4 — Read-only advisor via Pi (**MVP target**)
- Pi extension read-only tools (`cogigator_status`, `cogigator_snapshot`,
  `cogigator_analyze`) against the bridge; resilient connection mgmt; status widget. Bridge
  `/analyze` packages the cited snapshot/findings for Pi's model. Diagnostics quality pass
  against hand-built broken factories (starved assembler, blocked output, low power, missing
  fluid, missing build materials, low ore). Every answer cites `core_id`, `tick`, and the
  finding used.
- **Exit (MVP proven):** with a Core placed and a datacenter running, an operator asks via Pi
  why a cell is stalling and gets a **correct, state-grounded, cited** answer. **Zero world
  mutation. No cluster mutation yet** (still port-forwarded RCON).

> **What the MVP proves:** (1) **locality** — reasoning is confined to a Core's physical zone;
> (2) **grounding** — answers come from real, derived state, not guesses; (3) **manufactured
> cognition** — capability scales with what the factory builds; (4) the **transport + Pi loop**
> works end-to-end and is identical local vs. headless because it never depends on screenshots.

### Phase 5 — Watches & alerts (still polling, no UDP)
- Per-Core watches (threshold/condition/cooldown), evaluated in Lua, costing a Cognition
  trickle. Bridge polls with backoff and pushes batched/summarized alerts to Pi via
  `pi.sendMessage(..., { deliverAs: "followUp" })`. **Exit:** a watch fires a timely low-ore
  alert without the operator polling — no launch-flag change required.

### Phase 6 — Planner & the approval ledger
- Planner/Draftsman tiers; `cogigator_propose_action` (inert intent) in Pi; **approval as a
  command/UI flow** (`/cogigator-approve <id>`, `ctx.ui.confirm`, fail-closed without UI); the
  in-game ledger diff; ghost placement on approval only; mod re-validation + audit. **Exit:**
  the assistant proposes a local expansion; the operator reviews the diff in-game and commits;
  ghosts appear, audited.

### Phase 7 — Multi-Core scale & deconstruction
- Explicit Cogigator-Network view (each Core reports independently; cross-Core intents split
  per Core; overlaps flagged; differing snapshot ticks disclosed). Inference Matrix
  (multi-fluid) + cooling/heat loop; larger zones/cadence as Cognition scales; Demolition
  Draftsman tier. **Exit:** two Cores reason about adjacent cells and coordinate a
  non-overlapping, separately-approved proposal.

### Phase 8 — Kubernetes hardening (the first permanent cluster change)
- Promote the bridge to an in-cluster **Deployment** in the `factorio` namespace via GitOps —
  added to the `factorio-server` repo (ArgoCD auto-syncs) **or** a dedicated repo + ArgoCD
  Application. Talks to `factorio-rcon:27015`. Secrets (provider API key, RCON ref) via
  **SealedSecrets**, same pattern as existing secrets. Conservative resource
  requests/limits. Prometheus `/metrics` (the infra doc's suggested `cogigator_*` series) +
  stdout logs for Promtail/Loki; optional Grafana dashboard via GitOps. NetworkPolicy so only
  the bridge reaches RCON. Operator reaches the bridge via port-forward / Tailscale, **not**
  public ingress. Optional later: the in-game player chat surface backed by the bridge's
  (now justified) embedded assistant. **Exit:** an always-on, GitOps-managed bridge serves a
  grounded, headless assistant with metrics and audit, having touched the critical StatefulSet
  not at all.

---

## 9. Kubernetes deployment implications

| Concern | Decision |
|---|---|
| **Transport** | RCON to `factorio-rcon.factorio.svc.cluster.local:27015`. No UDP → **no StatefulSet edit, no launch-flag change** on the critical pod. |
| **Bridge placement** | Separate **Deployment** in the `factorio` namespace (infra Option A), *not* a sidecar — keeps the bridge's failure/resource domain off the game pod and lets us iterate without restarting the server. Sidecar only revisited if/when UDP is justified. |
| **GitOps** | Bridge manifests live in `factorio-server` repo (ArgoCD `prune+selfHeal` already on) or a dedicated repo + ArgoCD Application. **No manual `kubectl apply` for persistent state** — ArgoCD reverts drift. |
| **Secrets** | Provider API key + any RCON reference via **SealedSecrets/`kubeseal`**, mirroring existing `sealed-secret*.yaml`. Never in the mod, the Pi extension, `.pi` config, session entries, logs, or this repo. |
| **Resources** | Strict, conservative requests/limits — the cluster is busy and Factorio holds `2–3` CPU / `2–4Gi`. The bridge must be cheap; heavy analysis stays deterministic/cached, not per-tick. |
| **Observability** | `/metrics` exposes `cogigator_rcon_*`, `cogigator_snapshot_duration_seconds`, `cogigator_llm_*`, `cogigator_actions_*`. Logs to stdout/stderr for Promtail→Loki. Optional Grafana dashboard via `monitoring/dashboards/`. |
| **Access model** | Operator (Pi) reaches the bridge via `kubectl port-forward` or a private Tailscale path — **never public ingress** for a control surface. Treat live cluster state as "verify when connected" (kubeconfig/Tailscale may be required). |
| **Mod delivery** | Cogigator added to `k8s/config/mod-list.yaml` in the `factorio-server` repo; respect `UPDATE_MODS_ON_START`, and verify compatibility with the existing Space Age mod pack (`flib`, `stdlib2`, LTN, factoryplanner, etc.). Complement those planners — focus on *situated* observation/explanation/approved action, don't duplicate calculators. |
| **Blast radius** | The game StatefulSet is critical and autosaves every 10 min. Minimize restarts; the bridge is independently deployable; a bridge outage degrades the Core to a dumb status panel, never the game. |

---

## 10. Pi extension workstream

A **separate workstream**, started only after the bridge contract is stable (PI.md
sequencing). The extension is a **control surface + model-tool adapter**, never the game-control
runtime.

- **Location:** `~/dev/cogigator/.pi/extensions/cogigator/index.ts` (auto-discovered, supports
  `/reload`, loads only after the project is trusted).
- **Factory discipline:** do **not** start sockets/watchers/child processes/timers in the
  factory. Open the bridge connection / SSE / any port-forward child process in `session_start`
  or an explicit command; tear everything down in `session_shutdown` (idempotent).
- **Tools (read-only first):** `cogigator_status` (`/health`+`/version`, updates footer
  status), `cogigator_snapshot` (bounded scope, truncates + reports truncation),
  `cogigator_analyze` (bridge-side deterministic diagnostics + cited context bundle). Later:
  `cogigator_propose_action` (creates an **inert** intent), `cogigator_pending_actions`. Use
  `StringEnum`; pass `signal` into `fetch`; throw to mark errors; keep `content` small with
  rich data in `details`.
- **Commands:** `/cogigator-connect [endpoint]`, `/cogigator-disconnect`, `/cogigator-status`,
  `/cogigator-snapshot`, `/cogigator-actions`, `/cogigator-approve <id>`,
  `/cogigator-reject <id>`, `/cogigator-config`.
- **Approval is a command/UI flow, not an LLM-autonomous tool** (PI.md): model calls
  `propose_action` → user sees the widget → user runs `/cogigator-approve`, gated by
  `ctx.ui.confirm()`, **failing closed when `!ctx.hasUI`**.
- **UI:** footer `cogigator: disconnected|connected|degraded`; widget for pending actions /
  latest event / bridge warning; compact `renderCall`/`renderResult` (one-line collapsed,
  detail expanded). Guard by `ctx.mode` (tui vs rpc vs json/print).
- **Resilience:** endpoint in non-secret `.pi/cogigator.json` (trusted projects only) with a
  `COGIGATOR_BRIDGE_URL` env override; **never** store tokens in `.pi`/session state; short
  timeouts; exponential backoff on event streams; graceful "here's how to connect" when the
  bridge is down; don't spam the model with reconnect logs.
- **State:** rebuild from the active branch on `session_start`/`session_tree`; workflow-visible
  state in tool-result `details`, extension-only state via `pi.appendEntry`; on branch
  navigation, re-query the bridge for pending-action truth rather than trusting session memory.
- **Events:** add SSE/polling for watch alerts only after the read-only loop is solid; batch +
  summarize; inject via `pi.sendMessage(..., { triggerTurn: true, deliverAs: "followUp" })`.
- **Packaging:** keep project-local during iteration; promote to a `pi-package` (Pi core libs
  as `peerDependencies: "*"`) only if it becomes reusable.

**Pi workstream milestone (independent of any live mutation):** Pi connects to a
local/port-forwarded bridge; the model calls a bounded snapshot tool; the user sees bridge
status + pending-action state; **no action can mutate the world without explicit approval.**

---

## 11. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **UPS on a budget-limited pod** — zone scans stall a busy server. | High | Interval (not per-tick) sampling spread across ticks; entity caps; cache + diff; the Cognition "overloaded" state is the *gameplay-visible* expression of this budget. UPS is a release gate. |
| **Touching the critical StatefulSet** (esp. for UDP) risks the live game. | High | RCON-via-separate-Deployment needs zero StatefulSet change. UDP deferred behind explicit justification. Bridge is independently deployable. |
| **GitOps drift / accidental manual changes** reverted by ArgoCD. | Med | All persistent change via repos + ArgoCD; document the flow; never `kubectl apply` for durable state. |
| **RCON payload/chunking limits.** | Med | Derive + bound snapshots; chunk/reassemble in the bridge; file-output fallback for large dumps. |
| **LLM hallucination erodes trust.** | High | Diagnostics computed in Lua so the model *selects*, not invents; force citations (`core_id`/`tick`/finding); show the underlying numbers in-game. |
| **Unwanted world mutation.** | High | Default read-only; double enforcement (mod + bridge); approval ledger + apply-time re-validation + audit; admin tier off and flagged; fail closed without UI. |
| **Real LLM cost/latency** on a multiplayer server. | Med | **Wire in-game Cognition to real spend** (§4.3): cheap/cached/deterministic when Cognition is low, deeper model only when manufactured capacity allows. Cache snapshots; call the model on human turns / threshold alerts only. |
| **Cognition mechanic feels like a tax, not a toy.** | Med | Make it *visible and rewarding* — overload tints, drain-on-deep-think, clear "build more brain → think better" feedback. Playtest the formula; ship one good default curve. |
| **Mod-pack compatibility** with the existing Space Age stack. | Med | Pin Factorio version; reuse `flib`/`stdlib2`; integration-test against the actual `mod-list.yaml`; complement (not duplicate) existing planners. |
| **Multiplayer determinism / desync.** | High | All non-determinism lives in the bridge/Pi; the mod only *reads* and applies *approved* changes via normal construction; never inject randomness into the sim. |
| **Factorio 2.0 API churn** (`storage`, UDP flag, rendering). | Med | Pin version in `info.json`; isolate API touchpoints behind wrappers; test against the pinned build. |
| **Secret leakage** (provider key, RCON pw). | High | SealedSecrets only; never in mod/extension/`.pi`/logs/session/this repo; NetworkPolicy scopes RCON to the bridge. |

---

## 12. Open questions

1. **Cognition representation** — a force-scoped *network resource* (simplest, recommended for
   MVP) vs. a *physical cartridge* you belt/bot-deliver to Cores (spicier, more Factorio-puzzle,
   higher build cost). Fork to resolve via playtest.
2. **Cognition → capability curve** — exact mapping of throughput/buffer to cadence, depth,
   concurrency, and watch count; and the per-request "spend" costs. Needs tuning.
3. **Cognition ↔ real spend coupling** — how aggressively should in-game Cognition gate real
   model tier/context? A great mechanic, but must not make the assistant feel broken when a
   new player's datacenter is tiny.
4. **Core prototype** — `assembling-machine` (honest status, GUI hook) vs. simpler powered
   entity; which avoids misleading recipe/inventory semantics?
5. **Worksite sizing** — arbitrary rectangles vs. tiered snaps (16²/32²/64²) tied to compute
   tier and Cognition cost.
6. **Two-brain UX** — when (if) to add the bridge-embedded in-game chat for the 5 players vs.
   keeping Pi as the sole, operator-facing assistant. MVP leans Pi-only.
7. **Multiplayer authority** — who sets the force ceiling and who may approve ledger items?
8. **Watches: Lua vs. bridge** — simple thresholds in Lua (deterministic, cheap), conversational
   summaries in the bridge. Confirm the split.
9. **Blueprint provenance** — assistant-generated from scratch vs. template-based vs. only
   annotating/modifying player blueprints. (Generation is harder and riskier.)
10. **Bridge language** — Python (fastest provider-SDK iteration) vs. Go (single static
    container, cheap footprint for the busy cluster). Lean Python for MVP, revisit at Phase 8.
11. **Offline behavior** — Core with no bridge: silent monitor, last-cached display, or explicit
    error state. (Degrade to a dumb status panel.)
12. **Multi-fluid recipe shape** — how many fluid lines on the Inference Matrix before cooling
    becomes tedious rather than fun? Keep recipes loose until playtested.

---

## 13. MVP commitment

**The MVP is Phases 1–4:** a placed Core with a visible worksite, a real deterministic
snapshot, a working **Cognition economy** that makes thinking a manufactured resource, and a
**read-only advisor driven through Pi** that correctly explains a bottleneck from actual game
state — over **port-forwarded RCON**, with file-output for debugging, **zero world mutation**,
and **zero permanent cluster change.**

Everything that mutates the world (Phase 6), pushes alerts (Phase 5), scales across Cores
(Phase 7), or hardens into the cluster via GitOps (Phase 8) is **deferred** until the grounded,
manufactured-cognition advisor loop is demonstrably trustworthy — the brief's "prove the
concept before granting power" stance, now grounded in a real, critical, GitOps-managed
Factorio server.
