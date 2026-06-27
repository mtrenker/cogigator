/**
 * Cogigator Pi extension — variant-agnostic read-only tools
 *
 * Implements the §7 Pi display contract from:
 *   docs/experiments/2026-06-26-industrial-cognition-ab.contract.md
 *
 * Tools (LLM-callable, read-only):
 *   cogigator_status   — bridge health + version
 *   cogigator_snapshot — bounded snapshot (experimentId, variantId, scenarioId,
 *                        stationId, stationKind, tick, findings, degradation)
 *   cogigator_analyze  — deterministic cited analysis
 *
 * Commands (user-invocable):
 *   /cogigator-connect    — configure bridge endpoint
 *   /cogigator-status     — human-facing bridge health check
 *   /cogigator-snapshot   — interactive scenario/variant snapshot picker
 *   /cogigator-experiment — show current experiment + variants + scenarios
 *
 * Skipped per spike scope: approval UI, action intents, event streams,
 * port-forward management.
 *
 * Invariant: no tool may mutate game state. The bridge only exposes read-only
 * endpoints in the spike subset (§6 of the contract).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const STATUS_KEY = "cogigator";
const DEFAULT_ENDPOINT = "http://127.0.0.1:8787";
const REQUEST_TIMEOUT_MS = 8_000;

/** Closed enum — §5 of the contract. */
const SCENARIO_IDS = [
  "starved-assembler",
  "blocked-output",
  "missing-fluid",
  "low-power",
  "under-computed",
  "dense-cell-truncated",
] as const;

/** Closed enum — §1 of the contract. */
const VARIANT_IDS = ["cognition-flow", "capacity-vector"] as const;

// ---------------------------------------------------------------------------
// Session state (per-instance; not persisted across process restarts)
// ---------------------------------------------------------------------------

interface CogigatorState {
  endpoint: string;
  connected: boolean;
  /** True when the most recent snapshot reported degraded cognition. */
  degraded: boolean;
}

// ---------------------------------------------------------------------------
// Bridge HTTP utility
// ---------------------------------------------------------------------------

async function bridgeFetch(
  state: CogigatorState,
  path: string,
  options: RequestInit = {},
  signal?: AbortSignal,
): Promise<unknown> {
  const url = `${state.endpoint}${path}`;
  const timeoutController = new AbortController();
  const timeoutId = setTimeout(
    () => timeoutController.abort(),
    REQUEST_TIMEOUT_MS,
  );

  // Combine caller signal with our internal timeout signal
  const combinedSignal = signal
    ? AbortSignal.any
      ? AbortSignal.any([signal, timeoutController.signal])
      : timeoutController.signal // fallback: just use timeout
    : timeoutController.signal;

  try {
    const res = await fetch(url, {
      ...options,
      signal: combinedSignal,
    });

    if (!res.ok) {
      let detail = "";
      try {
        const body = await res.json() as any;
        detail = body?.error?.message ?? "";
      } catch {
        /* ignore parse error */
      }
      throw new Error(
        `Bridge returned ${res.status} for ${path}${detail ? `: ${detail}` : ""}`,
      );
    }

    return res.json();
  } finally {
    clearTimeout(timeoutId);
  }
}

// ---------------------------------------------------------------------------
// Display formatters (§7 Pi display contract)
//
// These functions are intentionally variant-agnostic: they iterate
// cognition.capacities generically without branching on variantId.
// ---------------------------------------------------------------------------

function statusLine(state: CogigatorState): string {
  if (!state.connected) return "cogigator: disconnected";
  return state.degraded ? "cogigator: degraded" : "cogigator: connected";
}

function formatFinding(f: any, index: number): string {
  const sev = f.severity ? `[${f.severity}] ` : "";
  const subject =
    f.subjectName ? ` (${f.subjectName})` : "";
  return `  ${index + 1}. ${sev}${f.code}${subject}: ${f.message}`;
}

function formatDegradation(degradation: any): string[] {
  if (!degradation) return ["  Degradation: unavailable"];
  const lines: string[] = [
    `  Degraded:  ${degradation.degraded}`,
    `  Level:     ${degradation.level ?? "none"}`,
  ];
  if (Array.isArray(degradation.effects) && degradation.effects.length > 0) {
    lines.push(`  Effects:   ${degradation.effects.join(", ")}`);
  }
  if (Array.isArray(degradation.reasons) && degradation.reasons.length > 0) {
    lines.push(`  Reasons:   ${degradation.reasons.join(", ")}`);
  }
  const flags = degradation.flags;
  if (flags && typeof flags === "object" && Object.keys(flags).length > 0) {
    const flagStr = Object.entries(flags)
      .map(([k, v]) => `${k}=${v}`)
      .join(", ");
    lines.push(`  Flags:     ${flagStr}`);
  }
  return lines;
}

function formatSnapshot(snapshot: any): string {
  const variant = snapshot.variant ?? {};
  const station = snapshot.station ?? {};
  const degradation = snapshot.cognition?.degradation;
  const findings: any[] = snapshot.findings ?? [];
  const capacities: any[] = snapshot.cognition?.capacities ?? [];

  const lines: string[] = [
    "=== Cogigator Snapshot ===",
    `Experiment:  ${snapshot.experimentId ?? "?"}`,
    `Variant:     ${variant.variantId ?? "?"} — ${variant.variantLabel ?? "?"}`,
    `Scenario:    ${snapshot.scenarioId ?? "?"}`,
    `Station:     ${station.stationId ?? "?"} [${station.stationKind ?? "?"}]`,
    `Tick:        ${snapshot.tick ?? "?"}`,
    `Truncated:   ${snapshot.truncated ?? false}`,
  ];

  // Capacities — rendered generically (no variantId branch)
  if (capacities.length > 0) {
    lines.push("\nCognition Capacities:");
    for (const cap of capacities) {
      const satStr = cap.satisfied ? "✓" : "✗";
      const bnStr = cap.bottleneck ? " [bottleneck]" : "";
      lines.push(
        `  ${satStr} ${cap.key} (${cap.label}): ${cap.value}/${cap.limit} ${cap.unit ?? ""}${bnStr}`,
      );
      if (cap.note) lines.push(`      ${cap.note}`);
    }
  }

  // Degradation state
  lines.push("\nDegradation:");
  lines.push(...formatDegradation(degradation));

  // Findings
  if (findings.length > 0) {
    lines.push(`\nFindings (${findings.length}):`);
    findings.forEach((f, i) => lines.push(formatFinding(f, i)));
  } else {
    lines.push("\nFindings: none");
  }

  // Omission / truncation detail
  const omitted = snapshot.omitted;
  if (omitted && omitted.reason !== "none" && omitted.entityCount > 0) {
    lines.push(
      `\nOmitted: ${omitted.entityCount} entities (reason: ${omitted.reason})`,
    );
  }

  return lines.join("\n");
}

function formatAnalysis(result: any): string {
  const citations = result.citations ?? {};
  const findings: any[] = result.findings ?? [];

  const lines: string[] = [
    "=== Cogigator Analysis ===",
    `Experiment:       ${result.experimentId ?? "?"}`,
    `Scenario:         ${result.scenarioId ?? "?"}`,
    `Variant:          ${result.variantId ?? "?"}`,
    `Citation:         station=${citations.stationId ?? "?"}, tick=${citations.tick ?? "?"}`,
    `Primary finding:  ${result.primaryFindingCode ?? "none"}`,
    ``,
    `Cognition explanation:`,
    `  ${result.cognitionExplanation ?? "none"}`,
  ];

  if (Array.isArray(citations.findingCodes) && citations.findingCodes.length > 0) {
    lines.push(`\nCited finding codes: ${citations.findingCodes.join(", ")}`);
  }

  if (findings.length > 0) {
    lines.push(`\nFindings (${findings.length}):`);
    findings.forEach((f, i) => lines.push(formatFinding(f, i)));
  }

  if (result.truncated) {
    lines.push("\n⚠ Response was truncated by the bridge.");
  }

  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Extension factory
// ---------------------------------------------------------------------------

export default function cogigator(pi: ExtensionAPI): void {
  // Mutable per-session state. Shared across all closures below.
  const state: CogigatorState = {
    endpoint: process.env.COGIGATOR_BRIDGE_URL ?? DEFAULT_ENDPOINT,
    connected: false,
    degraded: false,
  };

  // -------------------------------------------------------------------------
  // Tool: cogigator_status
  // -------------------------------------------------------------------------

  pi.registerTool({
    name: "cogigator_status",
    label: "Cogigator Status",
    description:
      "Check Cogigator bridge health and version. Returns connection state, " +
      "schema version, and bridge version. Read-only — does not mutate game state. " +
      "Always safe to call. Updates the footer status indicator.",
    promptSnippet: "cogigator_status() — check bridge health and version",
    promptGuidelines:
      "Call this first when you need to verify the bridge is reachable, or when " +
      "subsequent tools fail with connection errors.",
    parameters: Type.Object({}),

    async execute(_id, _params, signal, onUpdate, ctx) {
      onUpdate?.({
        content: [{ type: "text", text: "Checking Cogigator bridge…" }],
      });

      try {
        const [health, version] = (await Promise.all([
          bridgeFetch(state, "/health", {}, signal ?? undefined),
          bridgeFetch(state, "/version", {}, signal ?? undefined),
        ])) as [any, any];

        state.connected = health?.status === "ok";
        state.degraded = false;

        if (ctx?.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
        }

        const text = [
          `Status:          ${health?.status ?? "unknown"}`,
          `Server time:     ${health?.serverTime ?? "?"}`,
          `Bridge version:  ${version?.bridgeVersion ?? "?"}`,
          `Snapshot schema: ${version?.snapshotSchema ?? "?"}`,
          `Analyze schema:  ${version?.analyzeSchema ?? "?"}`,
          `Endpoint:        ${state.endpoint}`,
        ].join("\n");

        return {
          content: [{ type: "text", text }],
          details: { health, version, endpoint: state.endpoint },
        };
      } catch (err: any) {
        state.connected = false;

        if (ctx?.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
        }

        throw new Error(
          `Cannot reach Cogigator bridge at ${state.endpoint}: ${err.message}. ` +
            `Start the bridge with: PORT=8787 node bridge/server.mjs`,
        );
      }
    },
  });

  // -------------------------------------------------------------------------
  // Tool: cogigator_snapshot
  // -------------------------------------------------------------------------

  pi.registerTool({
    name: "cogigator_snapshot",
    label: "Cogigator Snapshot",
    description:
      "Fetch a bounded, read-only Cogigator snapshot from the bridge for a " +
      "given scenario and variant. Returns experimentId, variantId, variantLabel, " +
      "scenarioId, stationId, stationKind, tick, cognition capacities, degradation " +
      "state (degraded, level, effects), and findings (code + message). " +
      "Both variants use the same tool path — the extension never branches on variantId. " +
      "Does not mutate game state.",
    promptSnippet:
      "cogigator_snapshot(scenarioId, variantId) — read a fixture snapshot",
    promptGuidelines:
      "Use scenarioId values from the closed enum: starved-assembler, blocked-output, " +
      "missing-fluid, low-power, under-computed, dense-cell-truncated. " +
      "Use variantId values: cognition-flow (A) or capacity-vector (B). " +
      "The same schema is returned regardless of variant; parse it generically.",
    parameters: Type.Object({
      scenarioId: Type.String({
        description:
          "Scenario ID (closed enum): starved-assembler | blocked-output | " +
          "missing-fluid | low-power | under-computed | dense-cell-truncated",
      }),
      variantId: Type.String({
        description:
          "Variant ID (closed enum): cognition-flow | capacity-vector",
      }),
    }),

    async execute(_id, params, signal, onUpdate, ctx) {
      const { scenarioId, variantId } = params;

      onUpdate?.({
        content: [
          {
            type: "text",
            text: `Fetching snapshot: ${scenarioId} / ${variantId}…`,
          },
        ],
      });

      const snapshot = (await bridgeFetch(
        state,
        `/snapshot?scenarioId=${encodeURIComponent(scenarioId)}&variantId=${encodeURIComponent(variantId)}`,
        {},
        signal ?? undefined,
      )) as any;

      const degraded: boolean =
        snapshot.cognition?.degradation?.degraded === true;
      state.connected = true;
      state.degraded = degraded;

      if (ctx?.hasUI) {
        ctx.ui.setStatus(STATUS_KEY, statusLine(state));
      }

      const text = formatSnapshot(snapshot);

      return {
        content: [{ type: "text", text }],
        details: {
          // §7 display fields
          experimentId: snapshot.experimentId,
          variantId: snapshot.variant?.variantId,
          variantLabel: snapshot.variant?.variantLabel,
          scenarioId: snapshot.scenarioId,
          stationId: snapshot.station?.stationId,
          stationKind: snapshot.station?.stationKind,
          tick: snapshot.tick,
          findingCodes: (snapshot.findings ?? []).map((f: any) => f.code),
          degradation: snapshot.cognition?.degradation ?? null,
          truncated: snapshot.truncated,
        },
      };
    },
  });

  // -------------------------------------------------------------------------
  // Tool: cogigator_analyze
  // -------------------------------------------------------------------------

  pi.registerTool({
    name: "cogigator_analyze",
    label: "Cogigator Analyze",
    description:
      "Ask the Cogigator bridge for deterministic, non-LLM diagnostics for a " +
      "given scenario and variant. Returns cited findings (stationId + tick + " +
      "finding codes), primaryFindingCode, and a cognition explanation. " +
      "The bridge derives answers from fixtures — no external LLM is involved. " +
      "Read-only. Does not mutate game state.",
    promptSnippet:
      "cogigator_analyze(scenarioId, variantId[, question]) — cited deterministic analysis",
    promptGuidelines:
      "Always cite stationId, tick, and the finding codes from the result. " +
      "The question parameter is optional context — the findings are fixture-derived " +
      "regardless of the question text.",
    parameters: Type.Object({
      scenarioId: Type.String({
        description:
          "Scenario ID (closed enum): starved-assembler | blocked-output | " +
          "missing-fluid | low-power | under-computed | dense-cell-truncated",
      }),
      variantId: Type.String({
        description:
          "Variant ID (closed enum): cognition-flow | capacity-vector",
      }),
      question: Type.Optional(
        Type.String({
          description:
            "Optional natural-language question to contextualize the analysis. " +
            "The bridge echoes it but findings are fixture-derived.",
        }),
      ),
    }),

    async execute(_id, params, signal, onUpdate, ctx) {
      const { scenarioId, variantId, question } = params;

      onUpdate?.({
        content: [
          {
            type: "text",
            text: `Analyzing: ${scenarioId} / ${variantId}…`,
          },
        ],
      });

      const result = (await bridgeFetch(
        state,
        "/analyze",
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            scenarioId,
            variantId,
            question: question ?? "",
          }),
        },
        signal ?? undefined,
      )) as any;

      state.connected = true;
      state.degraded = false; // analyze doesn't give us a degraded flag directly

      if (ctx?.hasUI) {
        ctx.ui.setStatus(STATUS_KEY, statusLine(state));
      }

      const text = formatAnalysis(result);
      const citations = result.citations ?? {};
      const findings: any[] = result.findings ?? [];

      return {
        content: [{ type: "text", text }],
        details: {
          experimentId: result.experimentId,
          scenarioId: result.scenarioId,
          variantId: result.variantId,
          citations,
          primaryFindingCode: result.primaryFindingCode,
          findingCodes: findings.map((f: any) => f.code),
          cognitionExplanation: result.cognitionExplanation,
          truncated: result.truncated,
        },
      };
    },
  });

  // -------------------------------------------------------------------------
  // Command: /cogigator-connect
  // -------------------------------------------------------------------------

  pi.registerCommand("cogigator-connect", {
    description:
      "Configure and verify the Cogigator bridge endpoint. " +
      "Usage: /cogigator-connect [http://host:port] — omit to use interactive prompt.",

    async handler(args, ctx) {
      let newEndpoint = args.trim().replace(/\/$/, "");

      if (!newEndpoint) {
        if (ctx.hasUI) {
          newEndpoint = await ctx.ui.input(
            "Bridge endpoint URL",
            state.endpoint,
          );
          newEndpoint = newEndpoint?.trim().replace(/\/$/, "") ?? "";
        } else {
          // Non-interactive: keep current endpoint and just verify
          newEndpoint = state.endpoint;
        }
      }

      if (newEndpoint) {
        state.endpoint = newEndpoint;
      }

      // Verify connectivity
      try {
        const health = (await bridgeFetch(state, "/health")) as any;
        state.connected = health?.status === "ok";
        state.degraded = false;

        if (ctx.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
          ctx.ui.notify(
            `Connected to Cogigator bridge at ${state.endpoint}`,
            "info",
          );
        }
      } catch (err: any) {
        state.connected = false;

        if (ctx.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
          ctx.ui.notify(
            `Could not reach bridge at ${state.endpoint}: ${err.message}`,
            "error",
          );
        }
      }
    },
  });

  // -------------------------------------------------------------------------
  // Command: /cogigator-status
  // -------------------------------------------------------------------------

  pi.registerCommand("cogigator-status", {
    description:
      "Show Cogigator bridge health, version, and current connection endpoint.",

    async handler(_args, ctx) {
      try {
        const [health, version] = (await Promise.all([
          bridgeFetch(state, "/health"),
          bridgeFetch(state, "/version"),
        ])) as [any, any];

        state.connected = health?.status === "ok";
        state.degraded = false;

        if (ctx.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
          ctx.ui.notify(
            `Bridge OK — ${version?.bridgeVersion ?? "?"} at ${state.endpoint} ` +
              `(${health?.serverTime ?? "?"})`,
            "info",
          );
        }
      } catch (err: any) {
        state.connected = false;

        if (ctx.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
          ctx.ui.notify(
            `Bridge unavailable at ${state.endpoint}: ${err.message}. ` +
              `Run: PORT=8787 node bridge/server.mjs`,
            "error",
          );
        }
      }
    },
  });

  // -------------------------------------------------------------------------
  // Command: /cogigator-snapshot
  // -------------------------------------------------------------------------

  pi.registerCommand("cogigator-snapshot", {
    description:
      "Fetch a Cogigator snapshot interactively. " +
      "Usage: /cogigator-snapshot [scenarioId] [variantId]",

    async handler(args, ctx) {
      const parts = args.trim().split(/\s+/).filter(Boolean);
      let scenarioId = parts[0] ?? "";
      let variantId = parts[1] ?? "";

      if (!scenarioId) {
        if (ctx.hasUI) {
          scenarioId =
            (await ctx.ui.select(
              "Choose scenario",
              [...SCENARIO_IDS],
            )) ?? "";
        } else {
          if (ctx.hasUI) {
            ctx.ui.notify("Provide a scenarioId: /cogigator-snapshot <scenarioId> [variantId]", "error");
          }
          return;
        }
      }

      if (!variantId) {
        if (ctx.hasUI) {
          variantId =
            (await ctx.ui.select(
              "Choose variant",
              [...VARIANT_IDS],
            )) ?? "";
        } else {
          variantId = VARIANT_IDS[0]; // default to cognition-flow in non-UI mode
        }
      }

      if (!scenarioId || !variantId) {
        if (ctx.hasUI) {
          ctx.ui.notify("Scenario and variant are required.", "error");
        }
        return;
      }

      try {
        const snapshot = (await bridgeFetch(
          state,
          `/snapshot?scenarioId=${encodeURIComponent(scenarioId)}&variantId=${encodeURIComponent(variantId)}`,
        )) as any;

        state.connected = true;
        state.degraded = snapshot.cognition?.degradation?.degraded === true;

        if (ctx.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
          ctx.ui.notify(formatSnapshot(snapshot), "info");
        }
      } catch (err: any) {
        state.connected = false;
        if (ctx.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
          ctx.ui.notify(`Snapshot error: ${err.message}`, "error");
        }
      }
    },
  });

  // -------------------------------------------------------------------------
  // Command: /cogigator-experiment
  // -------------------------------------------------------------------------

  pi.registerCommand("cogigator-experiment", {
    description:
      "Show the current Cogigator experiment — id, both variants, and available scenarios.",

    async handler(_args, ctx) {
      try {
        const current = (await bridgeFetch(
          state,
          "/experiments/current",
        )) as any;

        state.connected = true;

        const variants: any[] = current.variants ?? [];
        const scenarios: string[] = current.scenarios ?? [];

        const variantLines = variants
          .map(
            (v: any) =>
              `  ${v.variantLetter ?? "?"}: ${v.variantId} — ${v.variantLabel ?? "?"}` +
              ` (${v.stationLabel ?? "?"}, inspired by ${v.inspiredBy ?? "?"})`,
          )
          .join("\n");

        const scenarioLine = scenarios.join(", ");

        if (ctx.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
          ctx.ui.notify(
            `Experiment: ${current.experimentId} | ` +
              `Variants: ${variants.map((v: any) => v.variantId).join(", ")}`,
            "info",
          );
        }

        // In RPC/print mode: output is delivered via ui.notify above;
        // in TUI mode the user can also see a richer view if needed.
        // The formatted details are returned for human consumption:
        const text = [
          `=== Cogigator Experiment ===`,
          `Experiment: ${current.experimentId}`,
          `Schema:     ${current.snapshotSchema ?? "?"}`,
          ``,
          `Variants:`,
          variantLines,
          ``,
          `Scenarios (${scenarios.length}):`,
          `  ${scenarioLine}`,
        ].join("\n");

        // Surface text via notification in TUI; in non-UI mode callers see
        // the notify fallback. The text is also appended so the LLM can see
        // it if this command is called from an agent context.
        if (ctx.hasUI) {
          ctx.ui.notify(text, "info");
        }
      } catch (err: any) {
        state.connected = false;
        if (ctx.hasUI) {
          ctx.ui.setStatus(STATUS_KEY, statusLine(state));
          ctx.ui.notify(
            `Failed to fetch experiment: ${err.message}`,
            "error",
          );
        }
      }
    },
  });

  // -------------------------------------------------------------------------
  // Lifecycle events
  // -------------------------------------------------------------------------

  pi.on("session_start", (_event, ctx) => {
    // Restore endpoint from env (may change between sessions in long-running Pi)
    state.endpoint =
      process.env.COGIGATOR_BRIDGE_URL ??
      state.endpoint ??
      DEFAULT_ENDPOINT;
    state.connected = false;
    state.degraded = false;

    ctx.ui?.setStatus(STATUS_KEY, statusLine(state));
  });

  pi.on("session_shutdown", () => {
    state.connected = false;
    state.degraded = false;
    // No long-lived resources to clean up (spike scope excludes event streams,
    // port-forwards, and WebSocket connections).
  });
}
