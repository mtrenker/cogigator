-- cogigator/scripts/common/registry.lua
-- Station registry stub.
-- Tracks registered observation stations (Cogigator Core / Field Station
-- entities) within a save. Each registered station has a stable stationId
-- that is emitted in snapshots (§2.2 of the contract).
--
-- SPIKE STATUS: Stub implementation — storage is a plain Lua table held in
-- global.cogigator.registry. No world mutation occurs here; stations are
-- registered by their existing unit_number only after they have been placed
-- by the player.
--
-- Tasks that populate this for real:
--   Task 004 (Variant A) / Task 005 (Variant B) — register/unregister events
--   Task 006 (common reports) — iterate stations when generating snapshots

local M = {}

-- ---------------------------------------------------------------------------
-- Initialisation
-- ---------------------------------------------------------------------------

--- Create and return a fresh registry state table.
--- Called from control.lua on_init; the result is stored in global.
--- @return table
function M.init()
  return {
    -- Map of station_id (string) → station_entry (table).
    stations = {},
    -- Monotonic counter for generating stable station ids.
    next_seq  = 1,
  }
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

--- Register an observation entity as a Cogigator station.
--- @param state    table   The registry state from global.cogigator.registry.
--- @param entity   LuaEntity   The Factorio entity being registered.
--- @param variant_id  string  The active variant id at time of registration.
--- @return string  The newly assigned station_id.
function M.register(state, entity, variant_id)
  -- Station id format: <station_kind>-<seq>
  -- station_kind comes from the variant descriptor; seq is a monotonic counter.
  local experiments = require("scripts.common.experiments")
  local descriptor  = experiments.get_variant(variant_id)
  local kind        = descriptor and descriptor.station_kind or "station"
  local station_id  = kind .. "-" .. state.next_seq
  state.next_seq    = state.next_seq + 1

  state.stations[station_id] = {
    station_id    = station_id,
    station_kind  = kind,
    variant_id    = variant_id,
    unit_number   = entity.unit_number,
    surface_name  = entity.surface.name,
    position      = { x = entity.position.x, y = entity.position.y },
    registered_at_tick = game.tick,
    status        = "live",  -- live | stale | offline | overloaded
  }
  log(string.format("[cogigator] registry.register: %s (unit=%d, variant=%s)",
    station_id, entity.unit_number, variant_id))
  return station_id
end

--- Unregister a station by its unit_number (e.g. on entity removal).
--- @param state   table
--- @param unit_number  int
--- @return boolean  true if a station was found and removed.
function M.unregister_by_unit(state, unit_number)
  for station_id, entry in pairs(state.stations) do
    if entry.unit_number == unit_number then
      state.stations[station_id] = nil
      log("[cogigator] registry.unregister: " .. station_id)
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------------

--- Retrieve a station entry by station_id.
--- @param state   table
--- @param station_id  string
--- @return table|nil
function M.get(state, station_id)
  return state and state.stations[station_id]
end

--- Return all station entries as an array.
--- @param state   table
--- @return table[]
function M.all(state)
  if not state then return {} end
  local result = {}
  for _, entry in pairs(state.stations) do
    result[#result + 1] = entry
  end
  return result
end

--- Return the number of registered stations.
--- @param state   table
--- @return int
function M.count(state)
  if not state then return 0 end
  local n = 0
  for _ in pairs(state.stations) do n = n + 1 end
  return n
end

-- ---------------------------------------------------------------------------
-- Status mutation (read-only in spike — only status field, not world state)
-- ---------------------------------------------------------------------------

--- Update the status field of a registered station.
--- This does NOT mutate the game world; it only updates the mod's own tracking.
--- @param state       table
--- @param station_id  string
--- @param status      string  live | stale | offline | overloaded
function M.set_status(state, station_id, status)
  local allowed = { live=true, stale=true, offline=true, overloaded=true }
  if not allowed[status] then
    error("[cogigator] registry.set_status: invalid status: " .. tostring(status))
  end
  local entry = state and state.stations[station_id]
  if entry then
    entry.status = status
  end
end

return M
