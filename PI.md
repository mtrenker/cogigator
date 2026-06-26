# Pi Extension Context for Cogigator

This document gives planning agents enough context to design a useful Pi extension for Cogigator. It summarizes Pi's extension system and recommends how Pi should connect to the Factorio/Cogigator solution.

Source docs consulted: Pi README, `docs/extensions.md`, `docs/tui.md`, `docs/rpc.md`, `docs/sdk.md`, `docs/packages.md`, and representative extension examples.

## What Pi is

Pi is a terminal coding-agent harness. It can be customized without forking Pi through:

- **Extensions**: TypeScript modules with tools, commands, event hooks, UI, providers, and runtime behavior.
- **Skills**: Markdown instruction packs loaded on demand.
- **Prompt templates**: Slash-command prompt snippets.
- **Themes**: Terminal UI colors.
- **Pi packages**: npm/git/local bundles of extensions/skills/prompts/themes.

For Cogigator, the relevant mechanism is a **project-local Pi extension** that gives the user and the LLM safe tools for observing the Factorio server, asking the Cogigator bridge for analysis, and approving/denying proposed actions.

## Extension locations and loading

Extensions are TypeScript modules loaded through `jiti`, so they usually do not require a build step.

Auto-discovered extension paths:

```text
~/.pi/agent/extensions/*.ts              # global
~/.pi/agent/extensions/*/index.ts        # global directory extension
.pi/extensions/*.ts                      # project-local
.pi/extensions/*/index.ts                # project-local directory extension
```

For this project, prefer:

```text
~/dev/cogigator/.pi/extensions/cogigator/index.ts
```

Use `pi -e ./path/to/extension.ts` only for quick tests. Auto-discovered locations support `/reload`.

Project-local extensions load only after the project is trusted. Pi asks before trusting a project with `.pi` resources. Interactive users can run `/trust`; non-interactive runs can use `--approve` for one run.

## Minimal extension shape

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function cogigator(pi: ExtensionAPI) {
  pi.registerCommand("cogigator-status", {
    description: "Show Cogigator bridge status",
    handler: async (_args, ctx) => {
      ctx.ui.notify("Cogigator extension loaded", "info");
    },
  });

  pi.registerTool({
    name: "cogigator_snapshot",
    label: "Cogigator Snapshot",
    description: "Read a concise Factorio/Cogigator snapshot from the bridge. Does not mutate the game.",
    parameters: Type.Object({}),
    async execute(_id, _params, signal, onUpdate, ctx) {
      onUpdate?.({ content: [{ type: "text", text: "Fetching Cogigator snapshot..." }] });
      // fetch(..., { signal })
      return { content: [{ type: "text", text: "snapshot unavailable in skeleton" }], details: {} };
    },
  });
}
```

The default export may be async, but **do not start sockets, file watchers, child processes, or timers from the factory**. Factories can run in invocations that never start a session. Start long-lived resources in `session_start` or in a command/tool that needs them, and clean them up in `session_shutdown`.

## Important extension capabilities

### LLM-callable tools

Use `pi.registerTool()` for tools the model can call.

A tool has:

- `name`: stable snake_case identifier.
- `label`: display label.
- `description`: shown to the model.
- `promptSnippet`: optional one-line entry in Pi's tool list.
- `promptGuidelines`: optional tool-specific instructions added to the system prompt while active.
- `parameters`: TypeBox schema.
- `prepareArguments`: optional backwards-compatibility shim for old sessions.
- `execute(toolCallId, params, signal, onUpdate, ctx)`: implementation.
- optional `renderCall` / `renderResult`: compact TUI rendering.

Best practices:

- Use `StringEnum` from `@earendil-works/pi-ai` for string enums instead of `Type.Union([...Type.Literal])`; this is more model-provider compatible.
- Check `signal?.aborted` or pass `signal` into `fetch`/subprocess helpers.
- Use `onUpdate` for progress, but keep updates concise.
- Throw errors to mark a tool result as failed (`isError: true`). Returning an error-shaped object is not enough.
- Truncate tool output to avoid exploding context. Pi's built-in defaults are 50KB and 2000 lines.
- If a custom tool mutates files, wrap the full read/modify/write window with `withFileMutationQueue(absPath, fn)` so parallel tool calls cannot overwrite each other.
- Normalize path-like parameters that may be prefixed with `@`.

### Commands

Use `pi.registerCommand("name", { description, handler })` for slash commands:

```text
/cogigator-status
/cogigator-connect
/cogigator-disconnect
/cogigator-snapshot
/cogigator-approve <action-id>
/cogigator-reject <action-id>
```

Commands receive an `ExtensionCommandContext`, which can also do session operations such as `ctx.reload()`, `ctx.newSession()`, `ctx.fork()`, and `ctx.waitForIdle()`.

If a command calls `ctx.reload()`, treat reload as terminal:

```ts
await ctx.reload();
return;
```

Code after reload runs in the old extension frame and should not assume old state is valid.

### Events

Extensions can subscribe to lifecycle events with `pi.on(event, handler)`.

Useful events for Cogigator:

- `session_start`: initialize session-scoped connection state, status widgets, autocomplete, and restore persisted state.
- `session_shutdown`: close WebSocket/SSE connections, file watchers, and child processes.
- `tool_call`: enforce permission gates or block dangerous built-in tool use.
- `tool_result`: sanitize or summarize noisy results.
- `before_agent_start`: inject current bridge status or guidance into the next turn.
- `agent_end` / `turn_end`: update UI, mark proposed actions, refresh widgets.
- `input`: transform special syntax such as `@factory` or `/cogi ...` if needed.
- `context`: remove stale extension context from model input.
- `model_select` / `thinking_level_select`: update status indicators.

`tool_call` can block a tool:

```ts
pi.on("tool_call", async (event, ctx) => {
  if (event.toolName === "cogigator_apply_action") {
    return { block: true, reason: "Direct application is disabled; use approval flow." };
  }
});
```

`event.input` is mutable in `tool_call`, but mutate cautiously; Pi does not re-validate after mutation.

### UI

Extension UI is available through `ctx.ui`.

Simple dialog methods:

```ts
await ctx.ui.select("Pick one", ["A", "B"]);
await ctx.ui.confirm("Apply action?", "This will modify game state.");
await ctx.ui.input("Endpoint", "http://127.0.0.1:8787");
await ctx.ui.editor("Edit plan", "prefill");
ctx.ui.notify("Done", "info"); // info | warning | error
```

Persistent UI:

```ts
ctx.ui.setStatus("cogigator", "bridge: connected");
ctx.ui.setWidget("cogigator", ["No pending actions"]);
ctx.ui.setTitle("pi - cogigator");
ctx.ui.setEditorText("/cogigator-status");
```

Complex terminal UI is possible with `ctx.ui.custom()`, `@earendil-works/pi-tui` components, and overlays. Use existing components (`SelectList`, `SettingsList`, `BorderedLoader`, `Text`, `Container`) rather than building from scratch.

Guard by mode:

- `ctx.mode === "tui"`: full terminal UI including `custom()` and custom components.
- `ctx.mode === "rpc"`: dialog/fire-and-forget UI works through JSON protocol; custom TUI components degrade/no-op.
- `ctx.mode === "json"` or `"print"`: no UI.
- `ctx.hasUI` is true in TUI and RPC, false in print/JSON.

For non-interactive runs, permission-sensitive actions should fail closed instead of prompting.

### Sending messages from an extension

Use these sparingly.

```ts
pi.sendMessage({
  customType: "cogigator-event",
  content: "External event: train jam detected",
  display: true,
}, { triggerTurn: true, deliverAs: "followUp" });

pi.sendUserMessage("Analyze the latest Cogigator event", { deliverAs: "followUp" });
```

Delivery modes:

- `steer`: deliver after current assistant turn's tool calls, before the next LLM call.
- `followUp`: deliver after the agent finishes all current work.
- `nextTurn`: queued for the next user prompt; does not trigger by itself.

When the agent is streaming, `sendUserMessage` requires a delivery mode.

### State persistence

Pi sessions are a tree. Branches matter.

Recommended patterns:

1. **Tool state in tool result `details`** when it affects model-visible workflow. Rebuild state from `ctx.sessionManager.getBranch()` on `session_start` and `session_tree`.
2. **Extension-only state in `pi.appendEntry(customType, data)`** when it should persist but not enter LLM context.
3. **Project config in `.pi/<extension>.json`** only for non-secret configuration, and only after checking `ctx.isProjectTrusted()`.
4. **Secrets never in session entries, logs, tool output, or config files.** Use environment variables, OS keychain, or Kubernetes/SealedSecrets.

Branch-aware restore example:

```ts
pi.on("session_start", (_event, ctx) => {
  const last = ctx.sessionManager
    .getBranch()
    .filter((e) => e.type === "custom" && e.customType === "cogigator-state")
    .pop();
  // restore from last?.data
});
```

## Packaging

For local project iteration, keep the extension in `.pi/extensions/cogigator/`.

For sharing/reuse, make a Pi package with `package.json`:

```json
{
  "name": "cogigator-pi-extension",
  "keywords": ["pi-package"],
  "dependencies": {},
  "peerDependencies": {
    "@earendil-works/pi-coding-agent": "*",
    "@earendil-works/pi-ai": "*",
    "@earendil-works/pi-tui": "*",
    "typebox": "*"
  },
  "pi": {
    "extensions": ["./extensions"]
  }
}
```

Runtime dependencies go in `dependencies`; Pi core packages imported by extensions should be `peerDependencies` with `"*"`.

Packages can be installed from npm, git, or local paths. Project-local package settings live in `.pi/settings.json` and only load after trust.

## RPC and SDK alternatives

Use an extension when Cogigator wants to enhance the normal Pi TUI with commands, tools, status, and approvals.

Use **Pi RPC mode** when an external application wants to drive Pi as a subprocess from any language:

```bash
pi --mode rpc --no-session
```

RPC uses strict LF-delimited JSONL over stdin/stdout. Split only on `\n`; do not use line readers that split on Unicode separators. It supports prompt, steer, follow_up, abort, session state, model control, command listing, compaction, bash, and streamed events. Extension UI dialogs are represented as `extension_ui_request` / `extension_ui_response` messages.

Use the **Pi SDK** when embedding Pi in a Node.js application and you want type-safe direct access to `AgentSession`, events, tools, resource loading, sessions, and runtime replacement.

For Cogigator, the recommended primary path is **Pi extension -> Cogigator bridge API**. RPC/SDK are optional later if Cogigator grows its own UI that must control Pi headlessly.

## Recommended Cogigator/Pi architecture

### Keep responsibilities separate

Do **not** put Factorio/RCON/LLM game-control logic directly inside the Pi extension.

Recommended split:

```text
Pi TUI / coding agent
  └─ project-local Cogigator Pi extension
       ├─ LLM-callable read-only tools
       ├─ approval commands/UI
       ├─ compact status widgets
       └─ connects to local bridge endpoint

Cogigator bridge process/pod
  ├─ owns Factorio RCON / UDP / file protocol details
  ├─ validates action intents
  ├─ maintains observation snapshots
  ├─ exposes narrow HTTP/SSE/WebSocket API
  └─ never exposes raw RCON publicly

Factorio mod/server
  ├─ produces deterministic observations
  ├─ accepts only validated, player-approved mutations
  └─ records an in-game approval/action ledger
```

The Pi extension should be a **control surface and model tool adapter**, not the authoritative game-control runtime.

### Bridge connection options

#### Development: local bridge or kubectl port-forward

For early development:

- Run the bridge locally, or
- port-forward an in-cluster `cogigator-bridge` service to localhost.

Example target endpoint:

```text
http://127.0.0.1:8787
```

The extension can provide `/cogigator-connect` to configure or start a port-forward, but long-running port-forward processes should be spawned as session-scoped child processes and killed on `session_shutdown`. Do not run long-lived `kubectl port-forward` through a blocking `pi.exec()` call.

#### In-cluster bridge

A future bridge Deployment in the `factorio` namespace can access:

```text
factorio-rcon.factorio.svc.cluster.local:27015
```

The Pi extension should still talk to the bridge, not directly to RCON. For local Pi access, expose the bridge through one of:

- `kubectl port-forward svc/cogigator-bridge ...`
- a private Tailscale-only endpoint
- a localhost tunnel

Avoid public ingress for control-plane operations unless there is strong authentication and authorization.

#### External event flow back into Pi

If Cogigator should notify Pi when something happens in-game, prefer one of:

- Extension opens a WebSocket/SSE stream to the bridge on `session_start`.
- Extension polls a lightweight `/events` endpoint with backoff.
- Bridge writes a local trigger file only in development.
- A separate application drives Pi in RPC mode.

When an event arrives, the extension can update a widget/status, or inject a follow-up message with `pi.sendMessage(..., { triggerTurn: true, deliverAs: "followUp" })`. Avoid auto-triggering noisy events; batch and summarize.

## Suggested bridge API contract

Use a versioned, narrow API. Example:

```text
GET  /health
GET  /version
GET  /snapshot?scope=core|site|surface&maxBytes=...
POST /analyze
POST /actions/propose
GET  /actions/pending
POST /actions/{id}/approve
POST /actions/{id}/reject
GET  /events/stream        # SSE or WebSocket, optional
GET  /metrics              # Prometheus, optional
```

Recommended response properties:

```json
{
  "schemaVersion": "cogigator.bridge.v1",
  "requestId": "uuid",
  "serverTime": "2026-06-26T00:00:00Z",
  "factorio": { "version": "2.0.x", "save": "my-server" },
  "data": {},
  "warnings": [],
  "truncated": false
}
```

Action intent shape:

```json
{
  "id": "action-uuid",
  "kind": "mark_map|place_blueprint|set_signal|send_chat|run_console_command",
  "summary": "Short human-readable description",
  "riskLevel": "none|low|medium|high",
  "requiresApproval": true,
  "createdBy": "pi-session-id-or-user",
  "preconditions": [],
  "payload": {},
  "expiresAt": "timestamp"
}
```

Bridge must validate preconditions and permissions again on approve. The extension UI is not a security boundary.

## Recommended Pi tools for Cogigator

Start with read-only tools:

### `cogigator_status`

Purpose: report bridge/server health.

- Calls `/health` and `/version`.
- Returns concise status.
- Updates `ctx.ui.setStatus("cogigator", ...)`.
- No game mutation.

### `cogigator_snapshot`

Purpose: get a bounded snapshot of the observed Factorio site/core.

Parameters:

```ts
{
  scope?: "core" | "site" | "surface";
  maxBytes?: number;
}
```

Rules:

- Default to compact snapshots.
- Bridge should derive diagnostics before sending to Pi/LLM.
- Tool must truncate and report truncation.
- No secrets, no raw RCON password, no excessive entity dumps.

### `cogigator_analyze`

Purpose: ask bridge to run deterministic/non-LLM diagnostics or package a context bundle.

Parameters:

```ts
{
  question: string;
  snapshotId?: string;
}
```

Rules:

- Prefer bridge-side deterministic analysis for throughput/starvation/backpressure.
- Pi LLM can explain or choose among bridge-generated facts.

### `cogigator_propose_action`

Purpose: create an inert action intent, not apply it.

Parameters:

```ts
{
  kind: string;
  summary: string;
  payload: object;
}
```

Rules:

- Returns action ID and risk level.
- Does not mutate the game.
- Records pending action in extension state/widget.

### `cogigator_pending_actions`

Purpose: list pending bridge action intents.

- Compact output for the LLM.
- Richer details in `details` for custom renderer.

### `cogigator_approve_action` / `cogigator_reject_action`

Purpose: approve or reject an action intent.

Important: approval should usually be a **command/UI flow**, not an LLM-autonomous tool. If implemented as a tool, it must require explicit user confirmation through `ctx.ui.confirm()` and fail closed when `ctx.hasUI` is false.

Better pattern:

```text
LLM calls cogigator_propose_action -> user sees widget/dialog -> user runs /cogigator-approve <id>
```

## Suggested commands and UI

Commands:

```text
/cogigator-connect [endpoint]
/cogigator-disconnect
/cogigator-status
/cogigator-snapshot
/cogigator-actions
/cogigator-approve <action-id>
/cogigator-reject <action-id>
/cogigator-config
```

UI behavior:

- Footer status: `cogigator: disconnected|connected|degraded`.
- Widget above editor: pending actions, latest event summary, or bridge warning.
- Confirmation dialog for every mutation approval.
- Optional overlay for action diff/details.
- Notifications for bridge disconnect/reconnect and rejected unsafe requests.

Use compact renderers for Cogigator tools so the terminal stays readable:

- collapsed result: one-line summary, risk, action count, truncation flag.
- expanded result: diagnostic details, JSON snippets, action payload preview.

## Resilience best practices

### Connection management

- Store endpoint in non-secret config, e.g. `.pi/cogigator.json`, only in trusted projects.
- Support `COGIGATOR_BRIDGE_URL` as an environment override.
- Never store API tokens in `.pi` or session state.
- Use short request timeouts and clear errors.
- Implement exponential backoff for background event streams.
- Degrade gracefully: tools should explain how to connect when bridge is unavailable.
- Do not spam the model with reconnect logs.

### Long-lived resources

- Start WebSocket/SSE/file watcher/port-forward only after `session_start` or explicit command.
- Track child processes/controllers in extension state.
- Close/abort everything in `session_shutdown`.
- Make shutdown idempotent.
- Avoid unbounded timers. Use backoff and clear intervals.

### Output and context control

- Keep tool `content` small and model-relevant.
- Put structured data in `details` for renderers/state, but do not dump huge payloads.
- Truncate output using Pi utilities or bridge-side limits.
- Report when data is truncated and provide an explicit follow-up path.
- Avoid sending every live event into the LLM. Batch, summarize, and let the user opt in.

### Safety and authorization

- RCON must never be public.
- The bridge must enforce permissions independently from Pi.
- All world-mutating actions require explicit user approval.
- Approval must include action summary, risk level, target surface/site, and payload preview.
- Bridge should verify preconditions at apply time.
- Keep an in-game or bridge-side audit ledger of approved/rejected/applied actions.
- Fail closed in non-UI modes.

### Branch/session correctness

- Rebuild extension state from the active branch on `session_start` and `session_tree`.
- Avoid global singleton state that ignores session changes.
- If a branch navigates away from an action proposal, make pending action state explicit by querying the bridge rather than relying only on session memory.
- Label important entries with `pi.setLabel(entryId, label)` if needed for navigation.

### Performance

- Do not poll high-frequency game state from Pi. The bridge should own sampling and aggregation.
- Keep Pi extension calls request/response and human-paced.
- Cache health/version briefly, but make snapshot data explicit and timestamped.
- Do not run heavy Factorio analysis in the Pi process.
- Avoid large custom UI re-renders; cache rendered lines and invalidate on state changes.

## Planning recommendation

A good implementation plan should add the Pi extension as a separate workstream after the bridge contract is defined:

1. Define bridge API schemas and action intent model.
2. Implement local stub bridge or mock endpoints for extension development.
3. Add `.pi/extensions/cogigator/index.ts` with read-only status/snapshot tools and `/cogigator-status`.
4. Add connection config and resilient health checks.
5. Add pending-action proposal/read UI.
6. Add explicit approval/rejection command flow.
7. Add event stream or polling only after the read-only loop is stable.
8. Package extension if it becomes reusable outside this repo.

The first extension milestone should not require live Factorio mutation. It should prove:

- Pi can connect to a local/port-forwarded bridge.
- The model can call a bounded snapshot tool.
- The user can see bridge status and pending action state.
- No action can mutate the world without explicit approval.
