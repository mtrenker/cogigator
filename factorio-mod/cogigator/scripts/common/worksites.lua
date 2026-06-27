-- cogigator/scripts/common/worksites.lua
-- Worksite registry stub.
-- A worksite is a rectangular region on a surface that a Cogigator station
-- observes. It corresponds to the §2.3 "worksite" field in snapshots.
--
-- Each station has at most one active worksite. Worksites are axis-aligned
-- rectangles in tile coordinates, on a single named surface (always "nauvis"
-- in the spike).
--
-- SPIKE STATUS: Stub implementation — stores worksite bounds in
-- global.cogigator.worksites. No area scan or entity enumeration occurs here;
-- that is the responsibility of the snapshot builder (Tasks 004/005/006).
--
-- Invariant: worksite registration DOES NOT enumerate or mutate entities.
-- It only records the bounding box so the snapshot builder knows what to scan.

local M = {}

-- ---------------------------------------------------------------------------
-- Initialisation
-- ---------------------------------------------------------------------------

--- Create and return a fresh worksite state table.
--- Called from control.lua on_init; the result is stored in global.
--- @return table
function M.init()
  return {
    -- Map of station_id (string) → worksite_entry (table).
    sites = {},
  }
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

--- Assign a rectangular worksite to a station.
--- @param state       table   The worksites state from global.cogigator.worksites.
--- @param station_id  string  The owning station's id (from registry.lua).
--- @param surface_name  string  Name of the surface (e.g. "nauvis").
--- @param bounds      table   { left, top, right, bottom } tile coordinates.
--- @return table  The created worksite entry (same shape as §2.3 worksite).
function M.assign(state, station_id, surface_name, bounds)
  -- Validate bounds shape.
  assert(type(bounds.left)   == "number", "bounds.left must be a number")
  assert(type(bounds.top)    == "number", "bounds.top must be a number")
  assert(type(bounds.right)  == "number", "bounds.right must be a number")
  assert(type(bounds.bottom) == "number", "bounds.bottom must be a number")
  assert(bounds.right > bounds.left,  "bounds.right must be > bounds.left")
  assert(bounds.bottom > bounds.top,  "bounds.bottom must be > bounds.top")

  local entry = {
    station_id   = station_id,
    surface      = surface_name,
    bounds       = {
      left   = bounds.left,
      top    = bounds.top,
      right  = bounds.right,
      bottom = bounds.bottom,
    },
    -- Derived convenience fields (§2.3).
    width        = bounds.right  - bounds.left,
    height       = bounds.bottom - bounds.top,
    assigned_at_tick = game and game.tick or 0,
  }
  state.sites[station_id] = entry
  log(string.format(
    "[cogigator] worksites.assign: station=%s  surface=%s  bounds=[%d,%d,%d,%d]  size=%dx%d",
    station_id, surface_name,
    bounds.left, bounds.top, bounds.right, bounds.bottom,
    entry.width, entry.height
  ))
  return entry
end

--- Remove the worksite assignment for a station.
--- @param state       table
--- @param station_id  string
--- @return boolean  true if a worksite was removed.
function M.release(state, station_id)
  if state and state.sites[station_id] then
    state.sites[station_id] = nil
    log("[cogigator] worksites.release: " .. station_id)
    return true
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------------

--- Return the worksite entry for a station, or nil if not assigned.
--- @param state       table
--- @param station_id  string
--- @return table|nil
function M.get(state, station_id)
  return state and state.sites[station_id]
end

--- Return all worksite entries as an array.
--- @param state   table
--- @return table[]
function M.all(state)
  if not state then return {} end
  local result = {}
  for _, entry in pairs(state.sites) do
    result[#result + 1] = entry
  end
  return result
end

--- Return the number of assigned worksites.
--- @param state   table
--- @return int
function M.count(state)
  if not state then return 0 end
  local n = 0
  for _ in pairs(state.sites) do n = n + 1 end
  return n
end

-- ---------------------------------------------------------------------------
-- Bounds helpers
-- ---------------------------------------------------------------------------

--- Return the worksite bounds as a Factorio BoundingBox table.
--- (Factorio uses {left_top={x,y}, right_bottom={x,y}} for area searches.)
--- @param entry  table  A worksite entry from M.get / M.all.
--- @return table  Factorio BoundingBox.
function M.to_bounding_box(entry)
  return {
    left_top     = { x = entry.bounds.left,  y = entry.bounds.top    },
    right_bottom = { x = entry.bounds.right, y = entry.bounds.bottom },
  }
end

return M
