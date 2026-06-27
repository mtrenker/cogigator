-- cogigator/scripts/variants/cognition-flow.lua
-- Variant A — Sightline + Cognition Flow (Claude-inspired)
--
-- "Two scarcities: where it can look, and how hard it can think."
--
-- Capacities (§3.2, Variant A — frozen by contract):
--   sightline       — observation reach / zone coverage          (tiles²)
--   cognitionFlow   — manufactured think-rate (throughput)       (cog/min)
--   cognitionBuffer — stored cognition for deep/burst requests   (cog)
--   memory          — retained history / context depth           (units)
--
-- Degradation flag (§3.3, Variant A):
--   overloaded — buffer near-empty AND flow below demand
--                → answers queued / deterministic-only mode
--
-- Contract reference: docs/experiments/2026-06-26-industrial-cognition-ab.contract.md
-- Upstream dependency: scripts/common/experiments.lua (Task 002)
--
-- Design principles:
--   • Pure data + pure functions. No Factorio API calls, no world reads.
--   • compute_cognition() is the single entry point for Task 006 (common reports).
--     Call it with worksite data from a real entity scan, or with nil/empty scan
--     for stub/fixture mode (returns sensible default values).
--   • The descriptor field is the §1 pure-data object from experiments.lua.
--     Downstream tasks (007 bridge, 008 Pi) read it from there — this module
--     just provides a local alias for convenience.
--   • Individual capacity_*() helpers are exported so Task 006 can call them
--     independently when computing one dimension at a time.
--
-- NO WORLD MUTATION anywhere in this module.

local experiments = require("scripts.common.experiments")

local M = {}

-- ---------------------------------------------------------------------------
-- §1 Descriptor — pure-data alias; authoritative copy lives in experiments.lua
-- ---------------------------------------------------------------------------

--- The frozen §1 variant descriptor for "cognition-flow".
--- Identical to experiments.get_variant("cognition-flow").
M.descriptor = experiments.get_variant("cognition-flow")

-- ---------------------------------------------------------------------------
-- Default limits
-- Tuned for a "comfortable mid-game worksite" (~32×32 tiles, one Cogigator Core).
-- Task 006 may supply real computed values via the scan argument; these serve
-- as denominator/limit defaults when no live data is available.
-- ---------------------------------------------------------------------------

local DEFAULTS = {
  sightline_tiles_sq  = 1024,  -- 32×32 tile worksite
  flow_cog_per_min    = 20,    -- cog/min demand at a moderate worksite
  buffer_cog          = 60,    -- 3 min of buffer at full flow (20 cog/min × 3)
  memory_units        = 10,    -- retained history slots
}

-- Fractional thresholds used for degradation severity and bottleneck detection.
local THRESHOLD = {
  partial = 0.75,  -- below this fraction → partial degradation
  severe  = 0.40,  -- below this fraction → severe degradation
}

-- ---------------------------------------------------------------------------
-- Internal helper: build a §3.1 capacity entry
-- ---------------------------------------------------------------------------

--- Create a §3.1 capacity entry from named fields.
--- @param key        string   Capacity key (one of capacityKeys).
--- @param label      string   Player-facing label.
--- @param value      number   Current produced/available amount.
--- @param limit      number   Demand or maximum for this dimension.
--- @param unit       string   Unit hint string.
--- @param note       string|nil  Optional build hint.
--- @return table  §3.1 capacity entry (bottleneck defaults to false; caller may override).
local function make_capacity(key, label, value, limit, unit, note)
  local satisfied = (limit <= 0) or (value >= limit)
  return {
    key        = key,
    label      = label,
    value      = value,
    limit      = limit,
    unit       = unit,
    satisfied  = satisfied,
    bottleneck = false,   -- set by compute_cognition() after all capacities are known
    note       = note,
  }
end

-- ---------------------------------------------------------------------------
-- Individual capacity builders (exported for Task 006 / tests)
-- ---------------------------------------------------------------------------

--- Build the §3.1 sightline capacity entry.
--- sightline = the area (tiles²) this station can currently observe.
--- Default: full worksite area.
---
--- @param worksite_entry  table|nil  From worksites.get(); uses width/height.
--- @param scan_value      number|nil  Override from a real entity scan (tiles² visible).
--- @return table  §3.1 capacity entry.
function M.capacity_sightline(worksite_entry, scan_value)
  local limit = DEFAULTS.sightline_tiles_sq
  if worksite_entry then
    local w = worksite_entry.width  or 0
    local h = worksite_entry.height or 0
    if w > 0 and h > 0 then
      limit = w * h
    end
  end

  -- In stub/spike mode the station sees its entire worksite.
  local value = scan_value or limit
  local note = nil
  if value < limit then
    note = "Observation reach below worksite area: "
           .. tostring(value) .. "/" .. tostring(limit) .. " tiles²."
           .. " Extend or reposition the Cogigator Core."
  end

  return make_capacity("sightline", "Sightline", value, limit, "tiles²", note)
end

--- Build the §3.1 cognitionFlow capacity entry.
--- cognitionFlow = manufactured think-rate (cog/min throughput from Datacenter modules).
---
--- @param flow_value  number|nil  Produced cog/min from entity scan. nil → use limit (full).
--- @return table  §3.1 capacity entry.
function M.capacity_cognition_flow(flow_value)
  local limit = DEFAULTS.flow_cog_per_min
  local value = (flow_value ~= nil) and flow_value or limit   -- stub: assume full flow

  local note = nil
  if value < limit then
    local ratio = (limit > 0) and (value / limit) or 1
    note = "Flow below demand: "
           .. string.format("%.1f", value) .. "/" .. tostring(limit) .. " cog/min."
    if ratio < THRESHOLD.severe then
      note = note .. " Urgently build more Cogitation Datacenter modules."
    else
      note = note .. " Build more Cogitation Datacenter modules."
    end
  end

  return make_capacity("cognitionFlow", "Cognition Flow", value, limit, "cog/min", note)
end

--- Build the §3.1 cognitionBuffer capacity entry.
--- cognitionBuffer = stored cognition available for deep / burst analysis requests.
---
--- @param buffer_value  number|nil  Current stored cog. nil → use limit (full buffer).
--- @return table  §3.1 capacity entry.
function M.capacity_cognition_buffer(buffer_value)
  local limit = DEFAULTS.buffer_cog
  local value = (buffer_value ~= nil) and buffer_value or limit   -- stub: full buffer

  local note = nil
  if value < limit then
    note = "Buffer depleted: "
           .. string.format("%.1f", value) .. "/" .. tostring(limit) .. " cog stored."
           .. " Burst and deep-analysis requests will queue or run deterministic-only."
  end

  return make_capacity("cognitionBuffer", "Cognition Buffer", value, limit, "cog", note)
end

--- Build the §3.1 memory capacity entry.
--- memory = retained history / context depth (shared key with Variant B).
---
--- @param memory_value  number|nil  Active memory slots in use. nil → use limit (full).
--- @return table  §3.1 capacity entry.
function M.capacity_memory(memory_value)
  local limit = DEFAULTS.memory_units
  local value = (memory_value ~= nil) and memory_value or limit   -- stub: full memory

  local note = nil
  if value < limit then
    note = "Memory below capacity: "
           .. tostring(value) .. "/" .. tostring(limit) .. " units retained."
           .. " Historical context depth reduced."
  end

  return make_capacity("memory", "Memory", value, limit, "units", note)
end

-- ---------------------------------------------------------------------------
-- Degradation helpers (exported for tests and Task 006 inspection)
-- ---------------------------------------------------------------------------

--- Determine whether the overloaded flag should be set.
--- Overloaded = BOTH cognitionFlow AND cognitionBuffer are below the partial threshold.
--- This is the Variant A condition for queued / deterministic-only answers.
---
--- @param flow_cap    table  §3.1 cognitionFlow capacity entry.
--- @param buffer_cap  table  §3.1 cognitionBuffer capacity entry.
--- @return boolean
function M.is_overloaded(flow_cap, buffer_cap)
  local flow_ratio   = (flow_cap.limit   > 0) and (flow_cap.value   / flow_cap.limit)   or 1
  local buffer_ratio = (buffer_cap.limit > 0) and (buffer_cap.value / buffer_cap.limit) or 1
  return (flow_ratio < THRESHOLD.partial) and (buffer_ratio < THRESHOLD.partial)
end

--- Compute the §3.3 degradation block from the ordered capacity list.
--- Returns a complete degradation table including the overloaded flag.
---
--- @param capacities  table[]  §3.1 capacity entries (all four, in order).
--- @return table  §3.3 degradation block.
function M.compute_degradation(capacities)
  -- Locate the two capacities needed for the overloaded check.
  local flow_cap, buffer_cap
  for _, cap in ipairs(capacities) do
    if cap.key == "cognitionFlow"   then flow_cap   = cap end
    if cap.key == "cognitionBuffer" then buffer_cap = cap end
  end

  -- Collect unsatisfied reason codes and track the worst ratio.
  local reasons   = {}
  local min_ratio = 1
  for _, cap in ipairs(capacities) do
    if not cap.satisfied then
      reasons[#reasons + 1] = cap.key .. "-below-demand"
      local ratio = (cap.limit > 0) and (cap.value / cap.limit) or 0
      if ratio < min_ratio then min_ratio = ratio end
    end
  end

  -- Evaluate the Variant A–specific overloaded flag.
  local overloaded = false
  if flow_cap and buffer_cap then
    overloaded = M.is_overloaded(flow_cap, buffer_cap)
  end
  if overloaded then
    reasons[#reasons + 1] = "buffer-empty-plus-low-flow"
  end

  -- Derive level.
  local degraded = (#reasons > 0)
  local level    = "none"
  if degraded then
    if min_ratio < THRESHOLD.severe then
      level = "severe"
    else
      level = "partial"
    end
  end

  -- Build player-facing effects list.
  local effects = {}
  if level == "partial" or level == "severe" then
    effects[#effects + 1] = "analysis-depth-reduced"
  end
  if level == "severe" then
    effects[#effects + 1] = "report-cadence-slowed"
  end
  if overloaded then
    effects[#effects + 1] = "answers-queued"
    effects[#effects + 1] = "deterministic-only"
  end

  return {
    degraded = degraded,
    level    = level,
    flags    = { overloaded = overloaded },
    reasons  = reasons,
    effects  = effects,
  }
end

-- ---------------------------------------------------------------------------
-- Top-level cognition block builder — primary entry point for Task 006
-- ---------------------------------------------------------------------------

--- Compute a complete §3 cognition block for Variant A.
---
--- Called by Task 006 (common reports) after entity scanning, or called in
--- stub/fixture mode with nil inputs (returns sensible default values, all
--- satisfied, degradation = none).
---
--- The `scan` argument is a free-form table produced by the entity scanner.
--- Only the following keys are read; all are optional:
---
---   scan.sightline_value  (number|nil) — observed tiles² (from range calculation)
---   scan.flow_value       (number|nil) — produced cog/min (from Datacenter entities)
---   scan.buffer_value     (number|nil) — stored cog (from Memory Bank entities)
---   scan.memory_value     (number|nil) — memory slots in use (from history store)
---
--- Returns a §3 cognition block ready to embed in a §2 snapshot envelope.
---
--- @param worksite_entry  table|nil   From worksites.get(); passed to capacity_sightline.
--- @param scan            table|nil   Entity scan result with optional numeric values.
--- @return table  §3 cognition block.
function M.compute_cognition(worksite_entry, scan)
  scan = scan or {}

  -- Build the four capacity entries in the canonical order declared by capacityKeys.
  local sight_cap  = M.capacity_sightline(worksite_entry, scan.sightline_value)
  local flow_cap   = M.capacity_cognition_flow(scan.flow_value)
  local buffer_cap = M.capacity_cognition_buffer(scan.buffer_value)
  local memory_cap = M.capacity_memory(scan.memory_value)

  local capacities = { sight_cap, flow_cap, buffer_cap, memory_cap }

  -- Compute degradation (includes the overloaded flag).
  local degradation = M.compute_degradation(capacities)

  -- Mark the single binding-constraint capacity as bottleneck = true.
  -- If multiple capacities are unsatisfied, the one with the lowest ratio wins.
  local min_ratio    = 1
  local bottleneck_i = nil
  for i, cap in ipairs(capacities) do
    if not cap.satisfied then
      local ratio = (cap.limit > 0) and (cap.value / cap.limit) or 0
      if ratio < min_ratio then
        min_ratio    = ratio
        bottleneck_i = i
      end
    end
  end
  if bottleneck_i then
    capacities[bottleneck_i].bottleneck = true
  end

  return {
    model       = "cognition-flow",
    capacities  = capacities,
    degradation = degradation,
  }
end

return M
