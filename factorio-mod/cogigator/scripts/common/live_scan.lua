-- cogigator/scripts/common/live_scan.lua
-- Read-only live snapshot extraction helpers for local Factorio smoke tests.
--
-- This module reads entities inside an assigned worksite and converts them to
-- the same lightweight entity summary shape used by reports.build_snapshot().
-- It never creates, changes, orders, or destroys game objects.

local M = {}

local REPRESENTATIVE_TYPES = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["mining-drill"] = true,
  ["transport-belt"] = true,
  ["inserter"] = true,
  ["pipe"] = true,
  ["container"] = true,
  ["logistic-container"] = true,
  ["radar"] = true,
  ["constant-combinator"] = true,
}

local function reverse_entity_status()
  local out = {}
  if defines and defines.entity_status then
    for name, value in pairs(defines.entity_status) do
      out[value] = name:gsub("_", "-")
    end
  end
  return out
end

local STATUS_NAMES = reverse_entity_status()

local function status_name(entity)
  if not (entity and entity.valid) then return "unknown" end
  local ok, status = pcall(function() return entity.status end)
  if not ok or status == nil then return "working" end
  return STATUS_NAMES[status] or tostring(status)
end

local function recipe_name(entity)
  if not (entity and entity.valid) then return nil end
  local ok, recipe = pcall(function()
    if entity.get_recipe then return entity.get_recipe() end
    return nil
  end)
  if ok and recipe then return recipe.name end
  return nil
end

local function position(entity)
  return {
    x = entity.position and entity.position.x or 0,
    y = entity.position and entity.position.y or 0,
  }
end

local function representative_entity(entity)
  return {
    unitNumber = entity.unit_number,
    name = entity.name,
    type = entity.type,
    status = status_name(entity),
    position = position(entity),
    powerState = status_name(entity),
    recipe = recipe_name(entity),
    inputs = {},
    outputs = {},
    fluids = {},
  }
end

local function count_by_type(entities)
  local by_type = {}
  for _, entity in ipairs(entities) do
    if entity.valid then
      by_type[entity.type] = (by_type[entity.type] or 0) + 1
    end
  end
  return by_type
end

--- Read entities in a worksite and produce a bounded summary input.
--- @param surface LuaSurface
--- @param bounding_box table Factorio BoundingBox
--- @param representative_cap number
--- @return table { totalCount, byType, representative }
function M.entities_in_area(surface, bounding_box, representative_cap)
  representative_cap = representative_cap or 32
  local entities = surface.find_entities_filtered({ area = bounding_box })
  local representative = {}

  for _, entity in ipairs(entities) do
    if entity.valid and REPRESENTATIVE_TYPES[entity.type] and #representative < representative_cap then
      representative[#representative + 1] = representative_entity(entity)
    end
  end

  return {
    totalCount = #entities,
    byType = count_by_type(entities),
    representative = representative,
  }
end

local function tile_is_blocked(tile)
  if not tile then return true end
  if tile.name == "out-of-map" then return true end
  local ok, blocked = pcall(function()
    if tile.collides_with then return tile.collides_with("water-tile") end
    return false
  end)
  return ok and blocked or false
end

--- Read a bounded tile summary for planning tools. This is deliberately small:
--- it exports only terrain names and blocked tile coordinates, never mutates.
--- @param surface LuaSurface
--- @param bounding_box table Factorio BoundingBox
--- @param tile_cap number
--- @return table { source, bounds, totalCount, blockedTiles, tiles }
function M.tiles_in_area(surface, bounding_box, tile_cap)
  tile_cap = tile_cap or 1024
  local left = math.floor(bounding_box.left_top.x)
  local top = math.floor(bounding_box.left_top.y)
  local right = math.ceil(bounding_box.right_bottom.x) - 1
  local bottom = math.ceil(bounding_box.right_bottom.y) - 1
  local tiles = {}
  local blocked = {}
  local total = 0

  for y = top, bottom do
    for x = left, right do
      total = total + 1
      if #tiles < tile_cap then
        local tile = surface.get_tile(x, y)
        local entry = { x = x, y = y, name = tile and tile.name or "unknown" }
        tiles[#tiles + 1] = entry
        if tile_is_blocked(tile) then
          blocked[#blocked + 1] = { x = x, y = y, name = entry.name }
        end
      end
    end
  end

  return {
    source = "factorio-live-local",
    bounds = { left = left, top = top, right = right, bottom = bottom },
    totalCount = total,
    blockedTiles = blocked,
    tiles = tiles,
    truncated = total > tile_cap,
    caps = { tiles = tile_cap },
  }
end

return M
