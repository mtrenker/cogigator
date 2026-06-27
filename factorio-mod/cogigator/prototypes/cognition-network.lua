-- cogigator/prototypes/cognition-network.lua
-- Read-only entity shell for the Cognition Network synthesis.
--
-- These prototypes make the mechanic visible in-game without adding any
-- assistant action or world-mutation behavior. Players may place/mined normal
-- Factorio entities; the mod only observes placement so status commands can
-- count Field Stations.

local function copy_base(kind, name)
  local prototype = data.raw[kind] and data.raw[kind][name]
  if not prototype then
    error("[cogigator] missing base prototype: " .. kind .. "/" .. name)
  end
  return table.deepcopy(prototype)
end

local function icon(path)
  return "__base__/graphics/icons/" .. path .. ".png"
end

local function entity_item(name, icon_path, order)
  return {
    type = "item",
    name = name,
    icon = icon(icon_path),
    icon_size = 64,
    subgroup = "production-machine",
    order = order,
    place_result = name,
    stack_size = 50,
  }
end

local function recipe(name, icon_path, ingredients, order)
  return {
    type = "recipe",
    name = name,
    icon = icon(icon_path),
    icon_size = 64,
    enabled = true,
    ingredients = ingredients,
    results = {{ type = "item", name = name, amount = 1 }},
    order = order,
  }
end

local field_station = copy_base("radar", "radar")
field_station.name = "cogigator-field-station"
field_station.localised_name = {"entity-name.cogigator-field-station"}
field_station.localised_description = {"entity-description.cogigator-field-station"}
field_station.minable = { mining_time = 0.2, result = "cogigator-field-station" }
field_station.energy_usage = "150kW"
field_station.max_distance_of_sector_revealed = 0
field_station.max_distance_of_nearby_sector_revealed = 0
field_station.energy_per_sector = "1MJ"
field_station.energy_per_nearby_scan = "50kJ"
field_station.integration_patch = nil
field_station.icons = nil
field_station.icon = icon("radar")
field_station.icon_size = 64
field_station.order = "z[cogigator]-a[field-station]"

local cognition_processor = copy_base("assembling-machine", "assembling-machine-1")
cognition_processor.name = "cogigator-cognition-processor"
cognition_processor.localised_name = {"entity-name.cogigator-cognition-processor"}
cognition_processor.localised_description = {"entity-description.cogigator-cognition-processor"}
cognition_processor.minable = { mining_time = 0.2, result = "cogigator-cognition-processor" }
cognition_processor.crafting_categories = {"crafting"}
cognition_processor.crafting_speed = 0.01
cognition_processor.energy_usage = "250kW"
cognition_processor.fixed_recipe = nil
cognition_processor.icons = nil
cognition_processor.icon = icon("assembling-machine-1")
cognition_processor.icon_size = 64
cognition_processor.order = "z[cogigator]-b[cognition-processor]"

local memory_bank = copy_base("container", "steel-chest")
memory_bank.name = "cogigator-memory-bank"
memory_bank.localised_name = {"entity-name.cogigator-memory-bank"}
memory_bank.localised_description = {"entity-description.cogigator-memory-bank"}
memory_bank.minable = { mining_time = 0.2, result = "cogigator-memory-bank" }
memory_bank.inventory_size = 8
memory_bank.icons = nil
memory_bank.icon = icon("steel-chest")
memory_bank.icon_size = 64
memory_bank.order = "z[cogigator]-c[memory-bank]"

local planning_relay = copy_base("constant-combinator", "constant-combinator")
planning_relay.name = "cogigator-planning-relay"
planning_relay.localised_name = {"entity-name.cogigator-planning-relay"}
planning_relay.localised_description = {"entity-description.cogigator-planning-relay"}
planning_relay.minable = { mining_time = 0.2, result = "cogigator-planning-relay" }
planning_relay.icons = nil
planning_relay.icon = icon("constant-combinator")
planning_relay.icon_size = 64
planning_relay.order = "z[cogigator]-d[planning-relay]"

local entities = {
  field_station,
  cognition_processor,
  memory_bank,
  planning_relay,
}

local items = {
  entity_item("cogigator-field-station", "radar", "z[cogigator]-a[field-station]"),
  entity_item("cogigator-cognition-processor", "assembling-machine-1", "z[cogigator]-b[cognition-processor]"),
  entity_item("cogigator-memory-bank", "steel-chest", "z[cogigator]-c[memory-bank]"),
  entity_item("cogigator-planning-relay", "constant-combinator", "z[cogigator]-d[planning-relay]"),
}

local recipes = {
  recipe("cogigator-field-station", "radar", {
    { type = "item", name = "electronic-circuit", amount = 5 },
    { type = "item", name = "iron-plate", amount = 10 },
  }, "z[cogigator]-a[field-station]"),
  recipe("cogigator-cognition-processor", "assembling-machine-1", {
    { type = "item", name = "electronic-circuit", amount = 8 },
    { type = "item", name = "iron-gear-wheel", amount = 5 },
    { type = "item", name = "iron-plate", amount = 10 },
  }, "z[cogigator]-b[cognition-processor]"),
  recipe("cogigator-memory-bank", "steel-chest", {
    { type = "item", name = "steel-plate", amount = 4 },
    { type = "item", name = "electronic-circuit", amount = 4 },
  }, "z[cogigator]-c[memory-bank]"),
  recipe("cogigator-planning-relay", "constant-combinator", {
    { type = "item", name = "electronic-circuit", amount = 5 },
    { type = "item", name = "copper-cable", amount = 5 },
  }, "z[cogigator]-d[planning-relay]"),
}

data:extend(entities)
data:extend(items)
data:extend(recipes)
