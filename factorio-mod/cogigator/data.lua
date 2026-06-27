-- cogigator/data.lua
-- Data stage entry point.
-- Registers read-only Cognition Network entity shells for the synthesis pass.
--
-- These prototypes make the design visible in-game. They do not grant the mod
-- any world-mutation capability; runtime code only observes placement/removal
-- of Cogigator Field Stations for status/registry bookkeeping.

require("prototypes.cognition-network")
