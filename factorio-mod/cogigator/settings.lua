-- cogigator/settings.lua
-- Mod settings definitions (data-settings stage).
-- Defines the active variant selector for the Industrial Cognition A/B spike.
-- Wire identifiers are kebab-case per §0 contract conventions.

data:extend({
  -- ---------------------------------------------------------------------------
  -- Active variant selector
  -- Determines which variant module is loaded at startup.
  -- Tasks 004 / 005 each implement one variant module; this setting picks one.
  -- ---------------------------------------------------------------------------
  {
    type    = "string-setting",
    name    = "cogigator-active-variant",
    setting_type = "startup",
    default_value = "cognition-flow",
    allowed_values = {
      "cognition-flow",    -- Variant A (inspired by claude-opus-4-8)
      "capacity-vector",   -- Variant B (inspired by gpt-5.5)
    },
    order   = "a",
  },

  -- ---------------------------------------------------------------------------
  -- Permission mode (read-only enforcement)
  -- Spike fixtures may only use read-only-advisor or silent-monitor.
  -- Mutating tiers exist in the enum but are never exercised in the spike.
  -- ---------------------------------------------------------------------------
  {
    type    = "string-setting",
    name    = "cogigator-permission-mode",
    setting_type = "startup",
    default_value = "read-only-advisor",
    allowed_values = {
      "silent-monitor",
      "read-only-advisor",
      -- Mutating tiers listed below are INTENTIONALLY disabled for the spike.
      -- Uncomment only after the spike is complete and security is reviewed.
      -- "planner",
      -- "construction-draftsman",
      -- "demolition-draftsman",
      -- "debug-executor",
    },
    order   = "b",
  },

  -- ---------------------------------------------------------------------------
  -- Snapshot entity cap
  -- Hard cap on representative[] entity count to prevent oversized payloads.
  -- ---------------------------------------------------------------------------
  {
    type    = "int-setting",
    name    = "cogigator-entity-cap",
    setting_type = "startup",
    default_value = 32,
    minimum_value = 1,
    maximum_value = 256,
    order   = "c",
  },
})
