-- cogigator/scripts/common/reports.lua
-- Common report generation (Task 006).
--
-- Builds the §2 snapshot envelope (cogigator.snapshot.v1) by:
--   1. resolving the *selected* variant module (Variant A / Variant B),
--   2. calling it through a shared cognition interface,
--   3. computing the IDENTICAL §4 findings vocabulary for either variant,
--   4. assembling the full camelCase §2 envelope.
--
-- The report code is VARIANT-AGNOSTIC (contract §10.2): it iterates
-- `cognition.capacities` generically and never branches on `variantId` to
-- build the snapshot structure. Only the cognition *values* and the variant
-- *metadata* differ between A and B. Both variants therefore produce
-- comparable reports with different capacity/degradation explanations and an
-- identical finding vocabulary (the Task 006 acceptance criterion).
--
-- Spike scope (contract / Task 006): reports use synthetic, deterministic,
-- fixture-like tables rather than live `surface.find_entities_filtered`
-- scans. Wiring real entity scans + UPS tuning is explicitly out of scope.
--
-- Contract reference: docs/experiments/2026-06-26-industrial-cognition-ab.contract.md
--
-- NO WORLD MUTATION anywhere in this module (pure data + pure functions).

local experiments = require("scripts.common.experiments")
local findings    = require("scripts.common.findings")

local M = {}

M.SCHEMA_VERSION = "cogigator.snapshot.v1"
M.EXPERIMENT_ID  = "industrial-cognition-ab"

-- Default cap on representative machines emitted per snapshot (§2.5 / §2.6).
local DEFAULT_REPRESENTATIVE_CAP = 8

-- ---------------------------------------------------------------------------
-- Variant metadata → camelCase wire object (§1)
-- The Lua descriptors use snake_case; §2 `variant` is the camelCase object.
-- ---------------------------------------------------------------------------

--- Convert a snake_case §1 variant descriptor to the camelCase wire object.
--- @param d table  experiments.get_variant(...) descriptor.
--- @return table  camelCase §1 variant metadata.
function M.descriptor_to_wire(d)
  if type(d) ~= "table" then return {} end
  return {
    experimentId     = d.experiment_id,
    variantId        = d.variant_id,
    variantLetter    = d.variant_letter,
    variantLabel     = d.variant_label,
    inspiredBy       = d.inspired_by,
    stationKind      = d.station_kind,
    stationLabel     = d.station_label,
    capacityKeys     = d.capacity_keys,
    degradationFlags = d.degradation_flags,
    tagline          = d.tagline,
  }
end

-- ---------------------------------------------------------------------------
-- Variant module resolution + shared cognition interface
-- ---------------------------------------------------------------------------

--- Lazily require the variant implementation module for a variant id.
--- Returns nil if the module is absent (graceful degradation during the spike).
--- @param variant_id string
--- @return table|nil
function M.resolve_variant_module(variant_id)
  if not variant_id then return nil end
  local ok, mod = pcall(require, "scripts.variants." .. variant_id)
  if ok and type(mod) == "table" then
    return mod
  end
  return nil
end

--- Call the selected variant module through the shared cognition interface.
---
--- The two variant modules expose different entry-point names and argument
--- shapes (Variant A: compute_cognition(worksite, scan); Variant B:
--- build_cognition(context)). This adapter normalizes the call so the common
--- report code stays variant-agnostic. Both return the SAME generic §3
--- cognition block shape ({ model, capacities[], degradation }).
---
--- @param variant_module table|nil   Resolved variant module.
--- @param descriptor      table       §1 descriptor (for fallback stub).
--- @param worksite_entry  table|nil   §2.3-shaped worksite (snake/camel compatible).
--- @param scan            table|nil   Synthetic / live cognition inputs.
--- @param entities_block  table|nil   §2.5 entities block (camelCase).
--- @return table  §3 cognition block.
function M.compute_cognition(variant_module, descriptor, worksite_entry, scan, entities_block)
  scan = scan or {}

  if variant_module then
    -- Variant A interface (cognition-flow): compute_cognition(worksite, scan).
    if type(variant_module.compute_cognition) == "function" then
      return variant_module.compute_cognition(worksite_entry, scan)
    end
    -- Variant B interface (capacity-vector): build_cognition(context).
    if type(variant_module.build_cognition) == "function" then
      local entity_total = entities_block and entities_block.totalCount or 0
      local context = {
        worksite          = worksite_entry,
        entities          = { total_count = entity_total },
        capacities        = scan.capacities,
        demand            = scan.demand,
        history           = scan.history,
        planning_enabled  = scan.planning_enabled,
        planning_required = scan.planning_required,
        active_watches    = scan.active_watches,
        station_count     = scan.station_count,
        memory_required   = scan.memory_required,
        memory_units      = scan.memory_units,
      }
      return variant_module.build_cognition(context)
    end
  end

  -- No variant module available → emit a valid, fully-satisfied stub so the
  -- snapshot shape is always complete (graceful degradation).
  return M._stub_cognition(descriptor)
end

--- Build a fully-satisfied §3 cognition stub from a descriptor's capacity keys.
--- Used only when no variant module can be resolved (graceful degradation).
--- @param descriptor table|nil  §1 descriptor.
--- @return table  §3 cognition block stub.
function M._stub_cognition(descriptor)
  local caps = {}
  if descriptor and descriptor.capacity_keys then
    for _, key in ipairs(descriptor.capacity_keys) do
      caps[#caps + 1] = {
        key        = key,
        label      = key,
        value      = 1,
        limit      = 1,
        unit       = "units",
        satisfied  = true,
        bottleneck = false,
        note       = nil,
      }
    end
  end

  local flags = {}
  if descriptor and descriptor.degradation_flags then
    for _, flag in ipairs(descriptor.degradation_flags) do
      flags[flag] = false
    end
  end

  return {
    model       = descriptor and descriptor.variant_id or "unknown",
    capacities  = caps,
    degradation = { degraded = false, level = "none", flags = flags,
                    reasons = {}, effects = {} },
  }
end

-- ---------------------------------------------------------------------------
-- Entities block: bounded summary with honest truncation (§2.5 / §2.6)
-- ---------------------------------------------------------------------------

--- Build a bounded §2.5 entities block, capping the representative list and
--- recording honest §2.6 truncation. Returns (entities_block, omitted, truncated).
--- @param raw_entities table|nil  Synthetic entities { totalCount, byType, representative }.
--- @param cap          int        Max representative machines to keep.
--- @return table, table, boolean
local function build_entities(raw_entities, cap)
  raw_entities = raw_entities or {}
  local rep_in = raw_entities.representative or {}
  local by_type = raw_entities.byType or {}
  local total_count = raw_entities.totalCount or #rep_in

  local kept = {}
  local dropped = 0
  for i, e in ipairs(rep_in) do
    if i <= cap then
      kept[#kept + 1] = e
    else
      dropped = dropped + 1
    end
  end

  local entities_block = {
    totalCount     = total_count,
    byType         = by_type,
    representative = kept,
  }

  local truncated = dropped > 0
  local omitted
  if truncated then
    omitted = {
      entityCount = dropped,
      reason      = "entity-cap",
      caps        = { representative = cap },
    }
  else
    omitted = { entityCount = 0, reason = "none", caps = {} }
  end

  return entities_block, omitted, truncated
end

-- ---------------------------------------------------------------------------
-- Power block normalization (§2.4)
-- ---------------------------------------------------------------------------

local function build_power(raw_power)
  raw_power = raw_power or {}
  local satisfaction = raw_power.satisfaction
  if satisfaction == nil then satisfaction = 1.0 end
  local state = raw_power.state
  if state == nil then
    if satisfaction <= 0 then state = "none"
    elseif satisfaction < 1 then state = "low"
    else state = "ok" end
  end
  return {
    satisfaction = satisfaction,
    demandKw     = raw_power.demandKw or 0,
    supplyKw     = raw_power.supplyKw or 0,
    state        = state,
  }
end

-- ---------------------------------------------------------------------------
-- Station / worksite block normalization (§2.2 / §2.3)
-- ---------------------------------------------------------------------------

local function build_station(station_entry, descriptor, permission_mode)
  station_entry = station_entry or {}
  return {
    stationId       = station_entry.station_id or station_entry.stationId
                       or ((descriptor and descriptor.station_kind or "station") .. "-1"),
    stationKind     = descriptor and descriptor.station_kind or station_entry.station_kind,
    stationLabel    = descriptor and descriptor.station_label or station_entry.station_label,
    permissionMode  = permission_mode or "read-only-advisor",
    transportHealth = station_entry.transport_health or station_entry.transportHealth or "ok",
    status          = station_entry.status or "live",
  }
end

local function build_worksite(worksite_entry)
  worksite_entry = worksite_entry or {}
  local bounds = worksite_entry.bounds or { left = 0, top = 0, right = 0, bottom = 0 }
  local width  = worksite_entry.width
  local height = worksite_entry.height
  if width == nil then width = (bounds.right or 0) - (bounds.left or 0) end
  if height == nil then height = (bounds.bottom or 0) - (bounds.top or 0) end
  return {
    surface = worksite_entry.surface or "nauvis",
    bounds  = bounds,
    width   = width,
    height  = height,
  }
end

-- ---------------------------------------------------------------------------
-- Top-level snapshot builder (§2)
-- ---------------------------------------------------------------------------

--- Build a complete §2 snapshot envelope for one station × variant.
---
--- Backward-compatible with the Task 002 scaffold signature
--- (station_entry, worksite_entry, variant_descriptor, tick). The 5th `opts`
--- argument carries Task 006 inputs:
---   opts.variant_module    table|nil  Pre-resolved variant module (else lazily required).
---   opts.scan              table|nil  Cognition inputs (synthetic or live).
---   opts.entities          table|nil  Synthetic { totalCount, byType, representative }.
---   opts.power             table|nil  Synthetic §2.4 power.
---   opts.scenario_id       string|nil  §5 scenario id.
---   opts.permission_mode   string|nil  Defaults "read-only-advisor".
---   opts.representative_cap int|nil    Defaults DEFAULT_REPRESENTATIVE_CAP.
---   opts.request_id        string|nil  Defaults zero-uuid.
---   opts.server_time       string|nil  ISO-8601; stamped by caller/bridge.
---   opts.metrics           table|nil  metrics state table to instrument.
---
--- @return table  §2 snapshot envelope (camelCase). expectedDiagnosis is never
---                emitted (fixtures-only, §2.7).
function M.build_snapshot(station_entry, worksite_entry, variant_descriptor, tick, opts)
  opts = opts or {}
  tick = tick or 0
  local descriptor = variant_descriptor or experiments.active_variant()

  local variant_module = opts.variant_module
    or M.resolve_variant_module(descriptor and descriptor.variant_id)

  -- 1. Bounded entities summary + honest truncation.
  local cap = opts.representative_cap or DEFAULT_REPRESENTATIVE_CAP
  local entities_block, omitted, truncated = build_entities(opts.entities, cap)

  -- 2. Power.
  local power_block = build_power(opts.power)

  -- 3. Cognition via the shared variant interface (variant-distinguishing).
  local cognition = M.compute_cognition(
    variant_module, descriptor, worksite_entry, opts.scan, entities_block
  )

  -- 4. Station / worksite.
  local station_block  = build_station(station_entry, descriptor, opts.permission_mode)
  local worksite_block = build_worksite(worksite_entry)

  -- 5. Findings — identical vocabulary for either variant (§4 / §10.3).
  local finding_list = findings.compute(
    entities_block, power_block, cognition, station_block, tick
  )

  -- 6. Optional instrumentation.
  if opts.metrics then
    local metrics = require("scripts.common.metrics")
    metrics.snapshot_built(opts.metrics, descriptor and descriptor.variant_id)
    metrics.findings_emitted(opts.metrics, #finding_list)
    if findings.is_under_computed(cognition) then
      metrics.degradation_observed(opts.metrics)
    end
  end

  -- 7. Assemble the camelCase §2 envelope.
  return {
    schemaVersion = M.SCHEMA_VERSION,
    experimentId  = M.EXPERIMENT_ID,
    scenarioId    = opts.scenario_id,
    variant       = M.descriptor_to_wire(descriptor),
    requestId     = opts.request_id or "00000000-0000-0000-0000-000000000000",
    serverTime    = opts.server_time,         -- stamped by the bridge layer
    factorio      = { version = "2.0.x", save = opts.save or "spike-fixture" },
    station       = station_block,
    worksite      = worksite_block,
    tick          = tick,
    cognition     = cognition,
    power         = power_block,
    entities      = entities_block,
    findings      = finding_list,
    omitted       = omitted,
    truncated     = truncated,
    -- expectedDiagnosis is fixtures-only (§2.7) and intentionally omitted here.
  }
end

-- ---------------------------------------------------------------------------
-- Synthetic, deterministic scenario corpus (spike fixtures-in-code)
-- One entry per §5 scenario id. Each carries entity / power inputs plus
-- BOTH variants' cognition inputs (Variant A reads its *_value keys; Variant B
-- reads capacities/demand). Healthy cognition leaves the keys nil so each
-- variant falls back to its satisfied defaults.
-- ---------------------------------------------------------------------------

local DEFAULT_WORKSITE = {
  surface = "nauvis",
  bounds  = { left = 0, top = 0, right = 32, bottom = 32 },
  width   = 32,
  height  = 32,
}

local SCENARIOS = {

  ["starved-assembler"] = {
    worksite = DEFAULT_WORKSITE,
    power    = { satisfaction = 1.0, demandKw = 300, supplyKw = 360, state = "ok" },
    entities = {
      totalCount = 14,
      byType = { ["assembling-machine"] = 3, ["transport-belt"] = 9, ["inserter"] = 2 },
      representative = {
        { unitNumber = 101, name = "assembling-machine-2", type = "assembling-machine",
          recipe = "iron-gear-wheel", status = "item-ingredient-shortage",
          position = { x = 4, y = 6 },
          inputs = { { item = "iron-plate", count = 0 } },
          outputs = { { item = "iron-gear-wheel", count = 12 } },
          fluids = {}, powerState = "working" },
        { unitNumber = 102, name = "transport-belt", type = "transport-belt",
          status = "belt-starved", position = { x = 3, y = 6 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
      },
    },
    scan = {},  -- healthy cognition for both variants
  },

  ["blocked-output"] = {
    worksite = DEFAULT_WORKSITE,
    power    = { satisfaction = 1.0, demandKw = 280, supplyKw = 360, state = "ok" },
    entities = {
      totalCount = 16,
      byType = { ["assembling-machine"] = 2, ["transport-belt"] = 12, ["inserter"] = 2 },
      representative = {
        { unitNumber = 201, name = "assembling-machine-2", type = "assembling-machine",
          recipe = "copper-cable", status = "full-output",
          position = { x = 10, y = 8 },
          inputs = { { item = "copper-plate", count = 40 } },
          outputs = { { item = "copper-cable", count = 100 } },
          fluids = {}, powerState = "working" },
        { unitNumber = 202, name = "transport-belt", type = "transport-belt",
          status = "belt-backed-up", position = { x = 11, y = 8 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
      },
    },
    scan = {},
  },

  ["missing-fluid"] = {
    worksite = DEFAULT_WORKSITE,
    power    = { satisfaction = 1.0, demandKw = 420, supplyKw = 500, state = "ok" },
    entities = {
      totalCount = 11,
      byType = { ["assembling-machine"] = 1, ["pipe"] = 8, ["pump"] = 2 },
      representative = {
        { unitNumber = 301, name = "chemical-plant", type = "assembling-machine",
          recipe = "sulfuric-acid", status = "fluid-ingredient-shortage",
          position = { x = 18, y = 14 },
          inputs = { { item = "sulfur", count = 30 } },
          outputs = {},
          fluids = { { fluid = "water", amount = 0 } },
          powerState = "working" },
      },
    },
    scan = {},
  },

  ["low-power"] = {
    worksite = DEFAULT_WORKSITE,
    power    = { satisfaction = 0.42, demandKw = 1200, supplyKw = 504, state = "low" },
    entities = {
      totalCount = 20,
      byType = { ["assembling-machine"] = 6, ["electric-mining-drill"] = 8, ["inserter"] = 6 },
      representative = {
        { unitNumber = 401, name = "electric-mining-drill", type = "electric-mining-drill",
          status = "no-power", position = { x = 22, y = 20 },
          inputs = {}, outputs = { { item = "iron-ore", count = 0 } },
          fluids = {}, powerState = "no-power" },
        { unitNumber = 402, name = "assembling-machine-3", type = "assembling-machine",
          recipe = "electronic-circuit", status = "no-power",
          position = { x = 24, y = 20 },
          inputs = { { item = "copper-cable", count = 8 } },
          outputs = {}, fluids = {}, powerState = "no-power" },
      },
    },
    scan = {},
  },

  -- Observation exists but cognition / capacity is degraded. Entities are
  -- nominally working, so `under-computed` is the headline finding for BOTH
  -- variants — with DIFFERENT cognition explanations.
  ["under-computed"] = {
    worksite = DEFAULT_WORKSITE,
    power    = { satisfaction = 1.0, demandKw = 300, supplyKw = 360, state = "ok" },
    entities = {
      totalCount = 9,
      byType = { ["assembling-machine"] = 4, ["transport-belt"] = 5 },
      representative = {
        { unitNumber = 501, name = "assembling-machine-2", type = "assembling-machine",
          recipe = "iron-gear-wheel", status = "working",
          position = { x = 6, y = 6 },
          inputs = { { item = "iron-plate", count = 50 } },
          outputs = { { item = "iron-gear-wheel", count = 20 } },
          fluids = {}, powerState = "working" },
      },
    },
    scan = {
      -- Variant A (cognition-flow): flow + buffer below demand → overloaded /
      -- deterministic-only. (flow 8/20 = 0.40, buffer 10/60 = 0.17 → severe.)
      flow_value   = 8,
      buffer_value = 10,
      -- Variant B (capacity-vector): scan budget below sampled-area demand →
      -- worksite-shrunk. (scan 300/1024 → partial.)
      capacities = { scan = 300 },
      demand     = { scan = 1024 },
    },
  },

  -- Dense cell: many entities; representative list must truncate honestly.
  ["dense-cell-truncated"] = {
    worksite = { surface = "nauvis",
                 bounds = { left = 0, top = 0, right = 48, bottom = 48 },
                 width = 48, height = 48 },
    power    = { satisfaction = 1.0, demandKw = 2400, supplyKw = 2600, state = "ok" },
    representative_cap = 8,
    entities = {
      totalCount = 87,
      byType = { ["assembling-machine"] = 24, ["transport-belt"] = 40,
                 ["inserter"] = 18, ["electric-furnace"] = 5 },
      representative = {
        { unitNumber = 601, name = "assembling-machine-3", type = "assembling-machine",
          recipe = "electronic-circuit", status = "item-ingredient-shortage",
          position = { x = 2, y = 2 },
          inputs = { { item = "copper-cable", count = 0 } },
          outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 602, name = "transport-belt", type = "transport-belt",
          status = "belt-backed-up", position = { x = 3, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 603, name = "assembling-machine-3", type = "assembling-machine",
          recipe = "iron-gear-wheel", status = "working", position = { x = 4, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 604, name = "electric-furnace", type = "electric-furnace",
          recipe = "iron-plate", status = "working", position = { x = 5, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 605, name = "inserter", type = "inserter",
          status = "inserter-blocked", position = { x = 6, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 606, name = "assembling-machine-2", type = "assembling-machine",
          recipe = "copper-cable", status = "working", position = { x = 7, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 607, name = "transport-belt", type = "transport-belt",
          status = "working", position = { x = 8, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 608, name = "assembling-machine-2", type = "assembling-machine",
          recipe = "iron-stick", status = "working", position = { x = 9, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        -- The following exceed the cap of 8 and must be reported as omitted.
        { unitNumber = 609, name = "inserter", type = "inserter",
          status = "working", position = { x = 10, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 610, name = "transport-belt", type = "transport-belt",
          status = "working", position = { x = 11, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 611, name = "assembling-machine-3", type = "assembling-machine",
          recipe = "electronic-circuit", status = "working", position = { x = 12, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
        { unitNumber = 612, name = "electric-furnace", type = "electric-furnace",
          recipe = "steel-plate", status = "working", position = { x = 13, y = 2 },
          inputs = {}, outputs = {}, fluids = {}, powerState = "working" },
      },
    },
    scan = {},
  },
}

--- List the available synthetic scenario ids (§5 order).
--- @return string[]
function M.scenario_ids()
  return {
    "starved-assembler", "blocked-output", "missing-fluid",
    "low-power", "under-computed", "dense-cell-truncated",
  }
end

--- Return the raw synthetic scenario definition (read-only) or nil.
--- @param scenario_id string
--- @return table|nil
function M.get_scenario(scenario_id)
  return SCENARIOS[scenario_id]
end

--- Build a snapshot for a synthetic scenario × variant. This is the primary
--- spike entry point that demonstrates the acceptance criterion: the same
--- scenario produces comparable reports for both variants, with different
--- capacity/degradation explanations and an identical finding vocabulary.
---
--- @param scenario_id string   One of §5 scenario ids.
--- @param variant_id  string   One of "cognition-flow" | "capacity-vector".
--- @param tick        int|nil  Snapshot tick (defaults to a deterministic value).
--- @param extra_opts  table|nil  Extra opts merged into build_snapshot (e.g. metrics).
--- @return table  §2 snapshot envelope.
function M.build_scenario_snapshot(scenario_id, variant_id, tick, extra_opts)
  local scenario = SCENARIOS[scenario_id]
  if not scenario then
    error("[cogigator] reports: unknown scenarioId: " .. tostring(scenario_id))
  end
  local descriptor = experiments.get_variant(variant_id)
  if not descriptor then
    error("[cogigator] reports: unknown variantId: " .. tostring(variant_id))
  end

  -- Synthetic station entry mirrors the variant's station kind.
  local station_entry = {
    station_id   = descriptor.station_kind .. "-1",
    station_kind = descriptor.station_kind,
    status       = "live",
  }

  local opts = {
    scenario_id        = scenario_id,
    scan               = scenario.scan,
    entities           = scenario.entities,
    power              = scenario.power,
    representative_cap = scenario.representative_cap or DEFAULT_REPRESENTATIVE_CAP,
  }
  if extra_opts then
    for k, v in pairs(extra_opts) do opts[k] = v end
  end

  return M.build_snapshot(station_entry, scenario.worksite, descriptor,
    tick or 123456, opts)
end

-- ---------------------------------------------------------------------------
-- Backward-compatible helpers (Task 002 scaffold API surface)
-- ---------------------------------------------------------------------------

--- Backward-compatible findings entry point (Task 002 signature).
--- Delegates to findings.from_entities (entity-derived findings only).
--- @param entities table[]|table  §2.5 representative list OR entities block.
--- @param tick     int
--- @return table[]
function M.compute_findings(entities, tick)
  -- Accept either a bare representative array or a full entities block.
  local block = entities
  if type(entities) == "table" and entities.representative == nil
     and entities[1] ~= nil then
    block = { representative = entities }
  end
  return findings.from_entities(block, tick)
end

--- Backward-compatible under-computed check (delegates to findings).
--- @param cognition table  §3 cognition block.
--- @return boolean
function M.is_under_computed(cognition)
  return findings.is_under_computed(cognition)
end

return M
