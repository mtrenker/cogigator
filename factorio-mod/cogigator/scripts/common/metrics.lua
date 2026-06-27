-- cogigator/scripts/common/metrics.lua
-- Metrics / instrumentation module (no-op stub).
-- Provides lightweight timing and counter hooks for the spike.
-- In the spike, metrics are read-only observational data captured inside
-- the Lua runtime — no external write, no network call, no file I/O.
--
-- This module is intentionally minimal. The bridge (Task 007) may expose
-- accumulated counters via /health or a /metrics endpoint, but metrics
-- collection here must never cause world mutation.

local M = {}

-- ---------------------------------------------------------------------------
-- In-memory accumulator (stored in global.cogigator.metrics at runtime)
-- ---------------------------------------------------------------------------

--- Initialise a fresh metrics state table.
--- Called from control.lua on_init alongside the registry and worksites inits.
--- @return table
function M.init()
  return {
    snapshots_built    = 0,
    findings_emitted   = 0,
    snapshot_errors    = 0,
    degraded_snapshots = 0,   -- snapshots whose cognition was degraded (§3.3)
    by_variant         = {},  -- map of variant_id → snapshot count
    command_calls      = {},  -- map of command_name → count
    -- Timing is approximate (Factorio tick-based, not wall-clock).
    last_snapshot_tick = nil,
  }
end

-- ---------------------------------------------------------------------------
-- Counters (all no-op in stub — Tasks 004/005/006 call these when ready)
-- ---------------------------------------------------------------------------

--- Increment the snapshot-built counter (optionally per variant).
--- @param state       table       global.cogigator.metrics
--- @param variant_id  string|nil  Variant that produced the snapshot.
function M.snapshot_built(state, variant_id)
  if state then
    state.snapshots_built = (state.snapshots_built or 0) + 1
    state.last_snapshot_tick = game and game.tick or nil
    if variant_id then
      state.by_variant = state.by_variant or {}
      state.by_variant[variant_id] = (state.by_variant[variant_id] or 0) + 1
    end
  end
end

--- Increment the degraded-snapshot counter (cognition was degraded, §3.3).
--- @param state  table  global.cogigator.metrics
function M.degradation_observed(state)
  if state then
    state.degraded_snapshots = (state.degraded_snapshots or 0) + 1
  end
end

--- Increment the findings-emitted counter.
--- @param state  table  global.cogigator.metrics
--- @param count  int    Number of findings emitted in this snapshot.
function M.findings_emitted(state, count)
  if state then
    state.findings_emitted = (state.findings_emitted or 0) + (count or 0)
  end
end

--- Increment the snapshot-error counter.
--- @param state  table  global.cogigator.metrics
function M.snapshot_error(state)
  if state then
    state.snapshot_errors = (state.snapshot_errors or 0) + 1
  end
end

--- Increment the per-command call counter.
--- @param state         table   global.cogigator.metrics
--- @param command_name  string
function M.command_called(state, command_name)
  if state then
    state.command_calls = state.command_calls or {}
    state.command_calls[command_name] = (state.command_calls[command_name] or 0) + 1
  end
end

-- ---------------------------------------------------------------------------
-- Summary (for bridge /health endpoint in Task 007)
-- ---------------------------------------------------------------------------

--- Return a plain-table summary of accumulated metrics.
--- All values are safe to serialise to JSON.
--- @param state  table  global.cogigator.metrics
--- @return table
function M.summary(state)
  if not state then
    return { snapshots_built = 0, findings_emitted = 0, snapshot_errors = 0,
             degraded_snapshots = 0, by_variant = {} }
  end
  return {
    snapshots_built    = state.snapshots_built    or 0,
    findings_emitted   = state.findings_emitted   or 0,
    snapshot_errors    = state.snapshot_errors    or 0,
    degraded_snapshots = state.degraded_snapshots or 0,
    by_variant         = state.by_variant         or {},
    command_calls      = state.command_calls      or {},
    last_snapshot_tick = state.last_snapshot_tick,
  }
end

return M
