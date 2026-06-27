-- cogigator/scripts/common/findings.lua
-- Shared findings vocabulary + deterministic findings computation (Task 006).
--
-- This module owns §4 of the spike contract:
--   docs/experiments/2026-06-26-industrial-cognition-ab.contract.md
--
-- The findings vocabulary is IDENTICAL across both variants (contract §4,
-- invariant §10.3). Variant modules (Task 004 / 005) own only the *cognition*
-- explanation; the finding `code`s emitted here never depend on `variantId`.
-- A consumer must never branch on the variant to parse findings.
--
-- Findings are computed DETERMINISTICALLY from observed entity / power /
-- cognition state — never invented by an LLM. The wire shape is camelCase
-- (contract §0 / §4.1).
--
-- NO WORLD MUTATION anywhere in this module (pure data + pure functions).

local M = {}

-- ---------------------------------------------------------------------------
-- §4.2 — Closed finding-code enum
-- ---------------------------------------------------------------------------

--- Ordered list of the 13 frozen finding codes (contract §4.2).
M.CODES = {
  "input-starved",
  "output-blocked",
  "no-recipe",
  "missing-fluid",
  "no-power",
  "low-power",
  "overheating",
  "inserter-blocked",
  "belt-starved",
  "belt-backed-up",
  "ghost-missing-material",
  "patch-below-threshold",
  "under-computed",
}

-- Set form for O(1) validation.
local CODE_SET = {}
for _, code in ipairs(M.CODES) do
  CODE_SET[code] = true
end

--- Validate a finding code against the closed enum.
--- @param code string
--- @return boolean
function M.is_valid_code(code)
  return CODE_SET[code] == true
end

-- ---------------------------------------------------------------------------
-- Default severities (contract §4.1: info | warning | error)
-- ---------------------------------------------------------------------------

local SEVERITY = {
  ["input-starved"]          = "error",
  ["output-blocked"]         = "warning",
  ["no-recipe"]              = "warning",
  ["missing-fluid"]          = "error",
  ["no-power"]               = "error",
  ["low-power"]              = "warning",
  ["overheating"]            = "warning",
  ["inserter-blocked"]       = "warning",
  ["belt-starved"]           = "info",
  ["belt-backed-up"]         = "warning",
  ["ghost-missing-material"] = "warning",
  ["patch-below-threshold"]  = "info",
  ["under-computed"]         = "warning",
}

--- Return the default severity for a finding code.
--- @param code string
--- @return string  "info" | "warning" | "error"
function M.severity_for(code)
  return SEVERITY[code] or "warning"
end

-- ---------------------------------------------------------------------------
-- Native (Factorio) entity status → normalized finding code
-- The keys use the kebab status labels surfaced in §2.5 (representative
-- machines may carry Factorio-native status strings). Several synonyms map to
-- the same normalized code so the diagnostic layer stays cross-variant.
-- ---------------------------------------------------------------------------

local STATUS_TO_CODE = {
  ["item-ingredient-shortage"]  = "input-starved",
  ["no-ingredients"]            = "input-starved",
  ["input-starved"]             = "input-starved",
  ["full-output"]               = "output-blocked",
  ["full-burnt-result"]         = "output-blocked",
  ["output-full"]               = "output-blocked",
  ["output-blocked"]            = "output-blocked",
  ["no-recipe"]                 = "no-recipe",
  ["fluid-ingredient-shortage"] = "missing-fluid",
  ["missing-required-fluid"]    = "missing-fluid",
  ["missing-fluid"]             = "missing-fluid",
  ["no-power"]                  = "no-power",
  ["no-fuel"]                   = "no-power",
  ["low-power"]                 = "low-power",
  ["overheating"]               = "overheating",
  ["inserter-blocked"]          = "inserter-blocked",
  ["belt-backed-up"]            = "belt-backed-up",
  ["belt-starved"]              = "belt-starved",
  ["ghost-missing-material"]    = "ghost-missing-material",
  ["patch-below-threshold"]     = "patch-below-threshold",
  -- Healthy / benign statuses map to nothing.
  ["working"]                   = nil,
  ["ok"]                        = nil,
  ["normal"]                    = nil,
}

--- Map a raw (native) entity status string to a normalized finding code.
--- @param status string|nil
--- @return string|nil  A §4.2 code, or nil if the status is benign/unknown.
function M.code_for_status(status)
  if status == nil then return nil end
  return STATUS_TO_CODE[status]
end

-- ---------------------------------------------------------------------------
-- Finding constructor (§4.1)
-- ---------------------------------------------------------------------------

--- Build a single §4.1 finding object (camelCase wire shape).
--- @param code              string   A §4.2 finding code.
--- @param subject_unit      int|nil  Subject entity unitNumber.
--- @param subject_name      string|nil  Subject prototype name.
--- @param message           string   One-line human-readable diagnosis.
--- @param evidence          table|nil  Free-form numeric/string evidence.
--- @param tick              int      The snapshot tick (citation anchor).
--- @param severity          string|nil  Override default severity.
--- @return table  §4.1 finding object.
function M.make_finding(code, subject_unit, subject_name, message, evidence, tick, severity)
  return {
    code              = code,
    severity          = severity or M.severity_for(code),
    subjectUnitNumber = subject_unit,
    subjectName       = subject_name,
    message           = message,
    evidence          = evidence or {},
    tick              = tick or 0,
  }
end

-- ---------------------------------------------------------------------------
-- Evidence + message helpers
-- ---------------------------------------------------------------------------

local function first(list)
  if type(list) == "table" then return list[1] end
  return nil
end

--- Derive a small evidence object + a human message for an entity finding.
--- @param code   string
--- @param entity table   §2.5 representative entity (camelCase).
--- @return table, string  evidence, message
local function evidence_and_message(code, entity)
  local name = entity.name or entity.type or "entity"

  if code == "input-starved" then
    local inp = first(entity.inputs) or {}
    local item = inp.item or "input"
    return { item = item, count = inp.count or 0 },
           string.format("%s starved: input %s empty.", name, item)

  elseif code == "output-blocked" then
    local out = first(entity.outputs) or {}
    local item = out.item or "product"
    return { item = item, count = out.count or 0 },
           string.format("%s output blocked: %s cannot leave.", name, item)

  elseif code == "missing-fluid" then
    local fl = first(entity.fluids) or {}
    local fluid = fl.fluid or fl.item or "fluid"
    return { fluid = fluid, amount = fl.amount or fl.count or 0 },
           string.format("%s waiting on fluid %s.", name, fluid)

  elseif code == "no-recipe" then
    return { status = entity.status },
           string.format("%s has no recipe set.", name)

  elseif code == "no-power" then
    return { status = entity.status, powerState = entity.powerState },
           string.format("%s is unpowered.", name)

  elseif code == "inserter-blocked" then
    return { status = entity.status },
           string.format("%s blocked: cannot pick up or drop.", name)

  elseif code == "belt-backed-up" then
    return { status = entity.status },
           string.format("Belt segment saturated at %s.", name)

  elseif code == "belt-starved" then
    return { status = entity.status },
           string.format("Belt segment empty at %s.", name)

  elseif code == "overheating" then
    return { status = entity.status },
           string.format("%s overheating: thermal limit reached.", name)

  elseif code == "ghost-missing-material" then
    return { status = entity.status },
           string.format("Ghost %s missing required build material.", name)

  elseif code == "patch-below-threshold" then
    return { status = entity.status },
           string.format("Resource patch %s below low-ore threshold.", name)
  end

  return { status = entity.status }, string.format("%s: %s.", name, code)
end

-- ---------------------------------------------------------------------------
-- Per-source finding builders
-- ---------------------------------------------------------------------------

--- Compute entity-derived findings from the §2.5 entities block.
--- Iterates `representative` in order; emits one finding per machine whose
--- native status maps to a §4.2 code. Deterministic (insertion order).
--- @param entities_block table|nil  §2.5 entities block (camelCase).
--- @param tick           int
--- @return table[]  Array of §4.1 findings.
function M.from_entities(entities_block, tick)
  local out = {}
  if type(entities_block) ~= "table" then return out end
  local rep = entities_block.representative
  if type(rep) ~= "table" then return out end

  for _, entity in ipairs(rep) do
    local code = M.code_for_status(entity.status)
    if code then
      local evidence, message = evidence_and_message(code, entity)
      out[#out + 1] = M.make_finding(
        code, entity.unitNumber, entity.name, message, evidence, tick
      )
    end
  end
  return out
end

--- Compute power-network findings from the §2.4 power block.
--- Emits `low-power` when satisfaction < 1, or `no-power` when state == "none".
--- @param power_block table|nil  §2.4 power block (camelCase).
--- @param tick        int
--- @return table[]  Array of §4.1 findings.
function M.from_power(power_block, tick)
  local out = {}
  if type(power_block) ~= "table" then return out end

  local satisfaction = power_block.satisfaction
  local state = power_block.state

  if state == "none" or satisfaction == 0 then
    out[#out + 1] = M.make_finding(
      "no-power", nil, nil,
      "Electric network unpowered: no supply.",
      { satisfaction = satisfaction or 0, state = state },
      tick
    )
  elseif (type(satisfaction) == "number" and satisfaction < 1) or state == "low" then
    out[#out + 1] = M.make_finding(
      "low-power", nil, nil,
      string.format("Electric network under-supplied: %.0f%% of demand met.",
        (satisfaction or 0) * 100),
      { satisfaction = satisfaction, demandKw = power_block.demandKw,
        supplyKw = power_block.supplyKw, state = state },
      tick
    )
  end
  return out
end

--- Detect the under-computed state from a §3 cognition block.
--- A station is under-computed when its cognition is degraded (any capacity
--- unsatisfied or any degradation flag set). Variant-agnostic.
--- @param cognition table|nil  §3 cognition block.
--- @return boolean
function M.is_under_computed(cognition)
  if type(cognition) ~= "table" then return false end
  local deg = cognition.degradation
  if type(deg) ~= "table" then return false end
  if deg.degraded == true then return true end
  -- Defensive: also treat an explicitly-set flag as under-computed.
  if type(deg.flags) == "table" then
    for _, set in pairs(deg.flags) do
      if set == true then return true end
    end
  end
  return false
end

--- Compute the cognition-derived `under-computed` finding, if any.
--- This is the only finding whose presence depends on the variant's cognition
--- output — but the CODE is identical across variants (contract §4.3).
--- @param cognition table|nil  §3 cognition block.
--- @param station   table|nil  §2.2 station block (for subject labelling).
--- @param tick      int
--- @return table[]  Array of 0 or 1 §4.1 findings.
function M.from_cognition(cognition, station, tick)
  local out = {}
  if not M.is_under_computed(cognition) then return out end

  local deg = cognition.degradation or {}
  local model = cognition.model or "station"
  local level = deg.level or "partial"
  out[#out + 1] = M.make_finding(
    "under-computed",
    nil,
    station and station.stationLabel or nil,
    string.format("Station cognition degraded (%s): insufficient capacity.", level),
    {
      model   = model,
      level   = level,
      reasons = deg.reasons or {},
      effects = deg.effects or {},
    },
    tick
  )
  return out
end

-- ---------------------------------------------------------------------------
-- Top-level entry point (used by reports.lua)
-- ---------------------------------------------------------------------------

--- Compute the full deterministic findings array for a snapshot.
--- Order is deterministic: entity findings (in representative order), then
--- power findings, then the cognition-derived under-computed finding.
---
--- The finding vocabulary is identical regardless of which variant produced
--- `cognition` — only the under-computed finding's *evidence* differs.
---
--- @param entities_block table|nil  §2.5 entities block.
--- @param power_block     table|nil  §2.4 power block.
--- @param cognition       table|nil  §3 cognition block.
--- @param station         table|nil  §2.2 station block.
--- @param tick            int
--- @return table[]  Array of §4.1 findings.
function M.compute(entities_block, power_block, cognition, station, tick)
  local out = {}

  for _, f in ipairs(M.from_entities(entities_block, tick)) do
    out[#out + 1] = f
  end
  for _, f in ipairs(M.from_power(power_block, tick)) do
    out[#out + 1] = f
  end
  for _, f in ipairs(M.from_cognition(cognition, station, tick)) do
    out[#out + 1] = f
  end

  return out
end

return M
