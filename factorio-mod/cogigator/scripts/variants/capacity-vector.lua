-- cogigator/scripts/variants/capacity-vector.lua
-- Variant B: Field Station + Capacity Vector.
--
-- Pure-data descriptor plus deterministic capacity/degradation helpers. This
-- module performs no Factorio reads or writes; common report code can pass in
-- already-collected snapshot context and render the returned generic cognition
-- block without branching on the variant.

local experiments = require("scripts.common.experiments")

local M = {}

M.descriptor = experiments.get_variant("capacity-vector")

local LABELS = {
  scan = "Scan",
  attention = "Attention",
  memory = "Memory",
  planning = "Planning",
}

local UNITS = {
  scan = "tiles²",
  attention = "slots",
  memory = "units",
  planning = "bool",
}

local DEFAULT_NOTES = {
  scan = "Shrink the worksite or add scan capacity.",
  attention = "Reduce active watches or add field stations.",
  memory = "Reduce retained history or add memory capacity.",
  planning = "Enable planning capacity for build-intent reasoning.",
}

local EFFECTS = {
  scan = "worksite-shrunk",
  attention = "watches-disabled",
  memory = "analysis-depth-reduced",
  planning = "planning-disabled",
}

local function count_list(value)
  return type(value) == "table" and #value or 0
end

local function positive_number(value, fallback)
  if type(value) == "number" and value >= 0 then
    return value
  end
  return fallback
end

local function table_value(context, table_name, key)
  local values = context and context[table_name]
  if type(values) == "table" then
    return values[key]
  end
  return nil
end

local function worksite_area(context)
  local worksite = context and context.worksite
  if type(worksite) ~= "table" then
    return 0
  end

  local width = positive_number(worksite.width, nil)
  local height = positive_number(worksite.height, nil)
  if width and height then
    return width * height
  end

  local bounds = worksite.bounds
  if type(bounds) == "table" then
    local left = positive_number(bounds.left, 0)
    local top = positive_number(bounds.top, 0)
    local right = positive_number(bounds.right, left)
    local bottom = positive_number(bounds.bottom, top)
    return math.max(0, right - left) * math.max(0, bottom - top)
  end

  return 0
end

local function entity_total(context)
  local entities = context and context.entities
  if type(entities) ~= "table" then
    return 0
  end
  return positive_number(entities.total_count, count_list(entities.representative))
end

local function capacity_entry(key, value, limit)
  local satisfied = limit <= 0 or value >= limit
  return {
    key = key,
    label = LABELS[key],
    value = value,
    limit = limit,
    unit = UNITS[key],
    satisfied = satisfied,
    bottleneck = false,
    note = satisfied and nil or DEFAULT_NOTES[key],
  }
end

local function configured_value(context, table_name, key, fallback)
  return positive_number(table_value(context, table_name, key), fallback)
end

--- Compute scan capacity: sampled area/entity-density budget per interval.
--- Context overrides:
---   capacities.scan or scan_capacity: available tiles² scan budget
---   demand.scan or scan_demand: required sampled area
function M.compute_scan(context)
  local default_demand = math.max(worksite_area(context), entity_total(context))
  local limit = positive_number(table_value(context, "demand", "scan"), nil)
    or positive_number(context and context.scan_demand, default_demand)
  local value = positive_number(table_value(context, "capacities", "scan"), nil)
    or positive_number(context and context.scan_capacity, limit)
  return capacity_entry("scan", value, limit)
end

--- Compute attention capacity: active stations/watches that can be tracked.
--- Context overrides:
---   capacities.attention or attention_slots: available watch slots
---   demand.attention or active_watches: required active watches
function M.compute_attention(context)
  local default_watches = positive_number(context and context.active_watches, nil)
    or positive_number(context and context.station_count, 1)
  local limit = configured_value(context, "demand", "attention", default_watches)
  local value = positive_number(table_value(context, "capacities", "attention"), nil)
    or positive_number(context and context.attention_slots, limit)
  return capacity_entry("attention", value, limit)
end

--- Compute memory capacity: retained history/context depth.
--- Context overrides:
---   capacities.memory or memory_units: available retained units
---   demand.memory or memory_required: required retained units
function M.compute_memory(context)
  local history = context and context.history
  local retained = type(history) == "table"
    and positive_number(history.retained_count, count_list(history.entries))
    or 0
  local default_required = math.max(1, retained)
  local limit = positive_number(table_value(context, "demand", "memory"), nil)
    or positive_number(context and context.memory_required, default_required)
  local value = positive_number(table_value(context, "capacities", "memory"), nil)
    or positive_number(context and context.memory_units, limit)
  return capacity_entry("memory", value, limit)
end

--- Compute planning capacity: build-intent reasoning gate.
--- Context overrides:
---   planning_enabled: boolean, defaults true
---   planning_required: boolean, defaults true
function M.compute_planning(context)
  local required = context == nil or context.planning_required ~= false
  local enabled = context == nil or context.planning_enabled ~= false
  local limit = required and 1 or 0
  local value = enabled and 1 or 0
  return capacity_entry("planning", value, limit)
end

local CAPACITY_FUNCTIONS = {
  scan = M.compute_scan,
  attention = M.compute_attention,
  memory = M.compute_memory,
  planning = M.compute_planning,
}

--- Return capacity entries in descriptor order.
function M.compute_capacities(context)
  local capacities = {}
  for _, key in ipairs(M.descriptor.capacity_keys) do
    capacities[#capacities + 1] = CAPACITY_FUNCTIONS[key](context or {})
  end
  M.mark_bottleneck(capacities)
  return capacities
end

--- Mark the lowest satisfaction ratio as the bottleneck.
function M.mark_bottleneck(capacities)
  local bottleneck
  local bottleneck_ratio = math.huge
  for _, capacity in ipairs(capacities or {}) do
    capacity.bottleneck = false
    if not capacity.satisfied then
      local ratio = capacity.limit > 0 and capacity.value / capacity.limit or 0
      if ratio < bottleneck_ratio then
        bottleneck = capacity
        bottleneck_ratio = ratio
      end
    end
  end
  if bottleneck then
    bottleneck.bottleneck = true
  end
end

--- Build normalized degradation from generic capacity entries.
function M.compute_degradation(capacities)
  local reasons = {}
  local effect_seen = {}
  local effects = {}
  local unsatisfied = 0

  for _, capacity in ipairs(capacities or {}) do
    if not capacity.satisfied then
      unsatisfied = unsatisfied + 1
      reasons[#reasons + 1] = capacity.key .. "-below-demand"
      local effect = EFFECTS[capacity.key]
      if effect and not effect_seen[effect] then
        effects[#effects + 1] = effect
        effect_seen[effect] = true
      end
    end
  end

  local level = "none"
  if unsatisfied == 1 then
    level = "partial"
  elseif unsatisfied > 1 then
    level = "severe"
  end

  return {
    degraded = unsatisfied > 0,
    level = level,
    flags = {},
    reasons = reasons,
    effects = effects,
  }
end

--- Build the complete §3 cognition block for Variant B.
function M.build_cognition(context)
  local capacities = M.compute_capacities(context or {})
  return {
    model = M.descriptor.variant_id,
    capacities = capacities,
    degradation = M.compute_degradation(capacities),
  }
end

return M
