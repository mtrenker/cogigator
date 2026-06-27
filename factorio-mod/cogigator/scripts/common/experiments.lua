-- cogigator/scripts/common/experiments.lua
-- Variant registry for the Industrial Cognition A/B spike.
-- Exposes the two frozen variant descriptors from §1 of the contract:
--   docs/experiments/2026-06-26-industrial-cognition-ab.contract.md
--
-- Field names below use snake_case internally (Lua convention); the bridge
-- layer (Task 007) serialises to camelCase per §0 contract conventions.
-- The Lua key  ↔  JSON wire field mapping is:
--   experiment_id   → experimentId
--   variant_id      → variantId
--   variant_letter  → variantLetter
--   variant_label   → variantLabel
--   inspired_by     → inspiredBy
--   station_kind    → stationKind
--   station_label   → stationLabel
--   capacity_keys   → capacityKeys
--   degradation_flags → degradationFlags

local M = {}

-- ---------------------------------------------------------------------------
-- Stable experiment constant (§0)
-- ---------------------------------------------------------------------------
M.EXPERIMENT_ID = "industrial-cognition-ab"

-- ---------------------------------------------------------------------------
-- Frozen variant descriptors (§1)
-- DO NOT change field values without amending the contract first.
-- ---------------------------------------------------------------------------
local VARIANTS = {

  -- Variant A — cognition-flow (inspired by claude-opus-4-8)
  ["cognition-flow"] = {
    experiment_id     = "industrial-cognition-ab",
    variant_id        = "cognition-flow",
    variant_letter    = "A",
    variant_label     = "Sightline + Cognition Flow",
    inspired_by       = "claude-opus-4-8",
    station_kind      = "core",
    station_label     = "Cogigator Core",
    -- Ordered list drives generic capacity rendering (§3.2).
    capacity_keys     = { "sightline", "cognitionFlow", "cognitionBuffer", "memory" },
    -- Variant-specific boolean degradation flags (§3.3).
    degradation_flags = { "overloaded" },
    tagline           = "Two scarcities: where it can look, and how hard it can think.",
  },

  -- Variant B — capacity-vector (inspired by gpt-5.5)
  ["capacity-vector"] = {
    experiment_id     = "industrial-cognition-ab",
    variant_id        = "capacity-vector",
    variant_letter    = "B",
    variant_label     = "Field Station + Capacity Vector",
    inspired_by       = "gpt-5.5",
    station_kind      = "field-station",
    station_label     = "Cogigator Field Station",
    -- Ordered list drives generic capacity rendering (§3.2).
    capacity_keys     = { "scan", "attention", "memory", "planning" },
    -- Variant B exposes no extra degradation flags (§3.3).
    degradation_flags = {},
    tagline           = "Four capacities that bound how much the station can perceive, track, recall, and plan.",
  },
}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Return the frozen descriptor table for a given variant_id, or nil.
--- @param variant_id string  One of "cognition-flow" | "capacity-vector"
--- @return table|nil
function M.get_variant(variant_id)
  return VARIANTS[variant_id]
end

--- Return a list of all known variant ids (stable insertion order).
--- @return string[]
function M.variant_ids()
  return { "cognition-flow", "capacity-vector" }
end

--- Return all variant descriptors keyed by variant_id.
--- @return table<string, table>
function M.all_variants()
  return VARIANTS
end

--- Return the descriptor for whichever variant is currently active,
--- reading from global state if available, or from the startup setting.
--- Must only be called during the runtime (control) stage.
--- @return table
function M.active_variant()
  local id
  if global and global.cogigator then
    id = global.cogigator.active_variant_id
  end
  if not id then
    id = settings.startup["cogigator-active-variant"].value
  end
  local descriptor = VARIANTS[id]
  if not descriptor then
    error("[cogigator] experiments.active_variant: unknown variant id: " .. tostring(id))
  end
  return descriptor
end

--- Validate that a given variant_id is in the closed enum.
--- @param variant_id string
--- @return boolean
function M.is_valid_variant(variant_id)
  return VARIANTS[variant_id] ~= nil
end

return M
