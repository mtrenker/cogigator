-- cogigator/control.lua
-- Runtime stage entry point for the Cogigator mod.
-- Handles on_init / on_load / on_configuration_changed lifecycle hooks,
-- registers console commands (read-only, variant-selectable), and
-- imports all shared and variant-specific scripts.
--
-- SPIKE INVARIANT: No world mutation path. All commands and handlers are
-- read-only. Mutating actions are structurally absent, not just gated.

local experiments = require("scripts.common.experiments")
local registry    = require("scripts.common.registry")
local worksites   = require("scripts.common.worksites")
local reports     = require("scripts.common.reports")
local metrics     = require("scripts.common.metrics")
local live_scan   = require("scripts.common.live_scan")

-- Factorio 2.0 renamed the persistent mod table from `global` to `storage`.
-- Keep the rest of the spike code readable while targeting 2.0.
local global = storage or global

local COGIGATOR_FIELD_STATION = "cogigator-field-station"
local DEFAULT_WORKSITE_SIZE = 32

-- ---------------------------------------------------------------------------
-- Active variant module (lazy-loaded based on startup setting)
-- ---------------------------------------------------------------------------
local function get_active_variant()
  local variant_id = settings.startup["cogigator-active-variant"].value
  local descriptor = experiments.get_variant(variant_id)
  if not descriptor then
    error("[cogigator] Unknown active variant: " .. tostring(variant_id))
  end
  -- Variant module lives at scripts/variants/<variant-id>/init.lua or, for
  -- flat modules, scripts/variants/<variant-id>.lua. Tasks 004 and 005
  -- populate these; until then we return a no-op stub.
  local ok, variant_module = pcall(require, "scripts.variants." .. variant_id .. ".init")
  if not ok then
    ok, variant_module = pcall(require, "scripts.variants." .. variant_id)
  end
  if not ok then
    -- Graceful degradation: variant module not yet implemented.
    variant_module = { descriptor = descriptor }
  end
  return variant_module
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
script.on_init(function()
  -- Initialise global state tables for this save.
  global.cogigator = global.cogigator or {}
  global.cogigator.registry  = registry.init()
  global.cogigator.worksites = worksites.init()
  global.cogigator.metrics   = metrics.init()
  global.cogigator.active_variant_id =
    settings.startup["cogigator-active-variant"].value

  log("[cogigator] on_init — active variant: "
    .. global.cogigator.active_variant_id)
end)

script.on_load(function()
  -- Re-establish metatable / upvalue references after save/load.
  -- No state mutation here; global already restored by the engine.
  log("[cogigator] on_load — active variant: "
    .. (global.cogigator and global.cogigator.active_variant_id or "unknown"))
end)

script.on_configuration_changed(function(data)
  -- Handle mod version upgrades or setting changes.
  -- Re-read active variant in case a setting was changed between saves.
  if global.cogigator then
    global.cogigator.active_variant_id =
      settings.startup["cogigator-active-variant"].value
    log("[cogigator] on_configuration_changed — active variant now: "
      .. global.cogigator.active_variant_id)
  end
end)

-- ---------------------------------------------------------------------------
-- Read-only Cognition Network entity shell bookkeeping
-- ---------------------------------------------------------------------------

local function ensure_state()
  global.cogigator = global.cogigator or {}
  global.cogigator.registry = global.cogigator.registry or registry.init()
  global.cogigator.worksites = global.cogigator.worksites or worksites.init()
  global.cogigator.metrics = global.cogigator.metrics or metrics.init()
  global.cogigator.active_variant_id = global.cogigator.active_variant_id
    or settings.startup["cogigator-active-variant"].value
end

local function entity_is_field_station(entity)
  return entity and entity.valid and entity.name == COGIGATOR_FIELD_STATION
end

local function default_worksite_bounds(entity)
  local half = DEFAULT_WORKSITE_SIZE / 2
  local x = math.floor(entity.position.x)
  local y = math.floor(entity.position.y)
  return {
    left = x - half,
    top = y - half,
    right = x + half,
    bottom = y + half,
  }
end

local function on_station_built(event)
  local entity = event.created_entity or event.entity
  if not entity_is_field_station(entity) then return end

  ensure_state()
  local variant_id = global.cogigator.active_variant_id
    or settings.startup["cogigator-active-variant"].value
  local station_id = registry.register(global.cogigator.registry, entity, variant_id)
  worksites.assign(
    global.cogigator.worksites,
    station_id,
    entity.surface.name,
    default_worksite_bounds(entity)
  )
end

local function on_station_removed(event)
  local entity = event.entity
  if not entity_is_field_station(entity) then return end
  ensure_state()
  local station = registry.get_by_unit(global.cogigator.registry, entity.unit_number)
  if station then
    worksites.release(global.cogigator.worksites, station.station_id)
  end
  registry.unregister_by_unit(global.cogigator.registry, entity.unit_number)
end

script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}, on_station_built)

script.on_event({
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy,
}, on_station_removed)

-- ---------------------------------------------------------------------------
-- Console commands (all read-only)
-- ---------------------------------------------------------------------------

-- /cogigator-status
-- Print the current experiment, active variant, and station registry count.
commands.add_command(
  "cogigator-status",
  { "cogigator-cmd-status-help" },
  function(event)
    local variant_id = global.cogigator and global.cogigator.active_variant_id
      or settings.startup["cogigator-active-variant"].value
    local descriptor = experiments.get_variant(variant_id)
    local station_count = registry.count(global.cogigator and global.cogigator.registry)
    local worksite_count = worksites.count(global.cogigator and global.cogigator.worksites)

    local msg = string.format(
      "[cogigator] experiment=%s  variant=%s (%s)  stations=%d  worksites=%d",
      experiments.EXPERIMENT_ID,
      variant_id,
      descriptor and descriptor.variant_letter or "?",
      station_count,
      worksite_count
    )
    if event.player_index then
      game.get_player(event.player_index).print(msg)
    else
      log(msg)
    end
  end
)

-- /cogigator-variant <variant-id>
-- Switch the active variant at runtime (changes saved in global; does NOT
-- alter the startup setting — requires map restart to persist across sessions).
commands.add_command(
  "cogigator-variant",
  { "cogigator-cmd-variant-help" },
  function(event)
    local new_id = event.parameter and event.parameter:match("^%S+$")
    local player = event.player_index and game.get_player(event.player_index)
    local function reply(msg)
      if player then player.print(msg) else log(msg) end
    end

    if not new_id then
      reply("[cogigator] Usage: /cogigator-variant <variant-id>  "
        .. "(known: " .. table.concat(experiments.variant_ids(), ", ") .. ")")
      return
    end
    if not experiments.get_variant(new_id) then
      reply("[cogigator] Unknown variant '" .. new_id .. "'.  "
        .. "Known: " .. table.concat(experiments.variant_ids(), ", "))
      return
    end
    if global.cogigator then
      global.cogigator.active_variant_id = new_id
    end
    reply("[cogigator] Active variant set to: " .. new_id
      .. " (runtime only; restart to persist)")
  end
)

-- /cogigator-worksites
-- Print assigned read-only worksite bounds.
commands.add_command(
  "cogigator-worksites",
  { "cogigator-cmd-worksites-help" },
  function(event)
    ensure_state()
    local player = event.player_index and game.get_player(event.player_index)
    local function reply(msg)
      if player then player.print(msg) else log(msg) end
    end

    local sites = worksites.all(global.cogigator.worksites)
    if #sites == 0 then
      reply("[cogigator] no worksites assigned")
      return
    end

    for _, site in ipairs(sites) do
      reply(string.format(
        "[cogigator] worksite station=%s surface=%s bounds=[%d,%d,%d,%d] size=%dx%d",
        site.station_id,
        site.surface,
        site.bounds.left,
        site.bounds.top,
        site.bounds.right,
        site.bounds.bottom,
        site.width,
        site.height
      ))
    end
  end
)

-- /cogigator-export-snapshot [station-id]
-- Export one live, read-only snapshot to script-output for local bridge import.
commands.add_command(
  "cogigator-export-snapshot",
  { "cogigator-cmd-export-snapshot-help" },
  function(event)
    ensure_state()
    local player = event.player_index and game.get_player(event.player_index)
    local function reply(msg)
      if player then player.print(msg) else log(msg) end
    end

    local station_id = event.parameter and event.parameter:match("^%S+$")
    local station
    if station_id then
      station = registry.get(global.cogigator.registry, station_id)
      if not station then
        reply("[cogigator] unknown station: " .. station_id)
        return
      end
    else
      station = registry.all(global.cogigator.registry)[1]
      if not station then
        reply("[cogigator] no Field Station registered; place one first")
        return
      end
    end

    local site = worksites.get(global.cogigator.worksites, station.station_id)
    if not site then
      reply("[cogigator] station has no worksite: " .. station.station_id)
      return
    end

    local surface = game.surfaces[site.surface]
    if not surface then
      reply("[cogigator] unknown surface: " .. tostring(site.surface))
      return
    end

    local variant_id = global.cogigator.active_variant_id
      or settings.startup["cogigator-active-variant"].value
    local descriptor = experiments.get_variant(variant_id)
    local representative_cap = settings.startup["cogigator-entity-cap"].value
    local entities = live_scan.entities_in_area(
      surface,
      worksites.to_bounding_box(site),
      representative_cap
    )

    local snapshot = reports.build_snapshot(station, site, descriptor, game.tick, {
      scenario_id = "live-local",
      save = "local-save",
      entities = entities,
      representative_cap = representative_cap,
      permission_mode = settings.startup["cogigator-permission-mode"].value,
      metrics = global.cogigator.metrics,
    })

    helpers.write_file(
      "cogigator/live-snapshot.json",
      helpers.table_to_json(snapshot) .. "\n",
      false
    )
    reply("[cogigator] exported live read-only snapshot for " .. station.station_id
      .. " to script-output/cogigator/live-snapshot.json")
  end
)

-- /cogigator-experiment
-- Print the full experiment descriptor for the current active variant.
commands.add_command(
  "cogigator-experiment",
  { "cogigator-cmd-experiment-help" },
  function(event)
    local variant_id = global.cogigator and global.cogigator.active_variant_id
      or settings.startup["cogigator-active-variant"].value
    local descriptor = experiments.get_variant(variant_id)
    local player = event.player_index and game.get_player(event.player_index)
    local function reply(msg)
      if player then player.print(msg) else log(msg) end
    end

    if not descriptor then
      reply("[cogigator] No descriptor found for variant: " .. tostring(variant_id))
      return
    end
    reply(string.format(
      "[cogigator] experiment=%s  variant=%s  letter=%s  label=%s  station=%s",
      descriptor.experiment_id,
      descriptor.variant_id,
      descriptor.variant_letter,
      descriptor.variant_label,
      descriptor.station_label
    ))
    reply("[cogigator] capacities: " .. table.concat(descriptor.capacity_keys, ", "))
  end
)

-- /cogigator-snapshot
-- Stub command — will be wired to actual snapshot logic in Tasks 004/005/006.
commands.add_command(
  "cogigator-snapshot",
  { "cogigator-cmd-snapshot-help" },
  function(event)
    local player = event.player_index and game.get_player(event.player_index)
    local function reply(msg)
      if player then player.print(msg) else log(msg) end
    end
    -- Task 004/005 variant modules will replace this stub.
    reply("[cogigator] snapshot command stub — variant modules not yet loaded.")
  end
)
