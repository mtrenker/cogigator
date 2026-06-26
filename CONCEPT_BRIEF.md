# Cogigator — Concept Brief

## Short pitch

**Cogigator** is a Factorio mod/companion-system concept that adds an in-world AI-linked machine to the factory. The player builds one or more local “thinking” structures that act as bounded observation and interaction points for an external assistant. Each structure gives the assistant a localized view of the factory and a limited ability to advise, plan, and optionally prepare changes through blueprints or construction ghosts.

The fantasy is not “an omniscient cheat bot.” It is closer to a strange industrial familiar living inside the factory: a machine-mind that watches a local production cell, diagnoses problems, suggests improvements, and helps the player execute plans.

## Name and tone

Working title: **Cogigator**

Tone directions to explore:

- weird industrial intelligence
- machine familiar / factory oracle
- practical production assistant
- slightly eccentric but useful
- integrated into Factorio’s systems rather than bolted on as a generic chatbot

The final presentation could lean cute, ominous, utilitarian, mystical, or retro-computational. Competing concepts should feel free to define their own personality and fiction.

## Core idea

The mod adds a craftable in-game structure, tentatively called an AI DataCenter, Cogigator Core, Thinking Engine, or similar. When placed, it defines a local operating zone. The external assistant can only inspect and reason about that zone unless the player builds more Cogigator structures elsewhere.

This locality is important:

- it keeps computation and data transfer manageable
- it makes the assistant feel physically grounded in the world
- it lets players delegate parts of the base cell-by-cell
- it creates interesting progression and design decisions
- it avoids giving the assistant unlimited global authority

## Emerging gameplay direction: industrialized cognition

One promising direction is that a “datacenter” should not be a single magical box. It could be a **collection of factory-built compute structures**: racks, thinking engines, coolant plants, signal processors, memory banks, or other assembly-like machines that together provide the Cogigator with capacity.

This is intentionally open-ended, but competing designs should explore whether AI capability can become a real Factorio production problem:

- The player may need to manufacture and maintain “compute,” “cognition,” “attention,” “inference,” or some other abstract resource.
- Datacenter components could have meaningful infrastructure needs: power, modules, cooling, fluids, waste heat, footprint, logistics, maintenance, or quality tiers.
- A custom assembly-machine-like entity with multiple fluid inputs is explicitly in scope if useful. For example, a high-tier compute building might require several fluid lines, making cooling and fluid routing part of the puzzle.
- More or better infrastructure could unlock larger observation zones, deeper analysis, faster responses, continuous monitoring, more simultaneous Cogigators, or more advanced action proposals.

The goal is not to prescribe a specific recipe chain. The goal is to let models compete on how to make “thinking” feel physically manufactured by the factory rather than granted for free.

## Desired player experience

A player should be able to ask things like:

- “Why is this science block stalling?”
- “Can this area produce 45 packs/min?”
- “What is missing from this blueprint?”
- “Suggest a better layout for this local production cell.”
- “Prepare ghosts for the next expansion, but ask before placing them.”
- “Watch this outpost and tell me when it runs low on ore.”

The assistant should answer using actual local game state, not guesses. Ideally it can also propose concrete actions, such as a blueprint string, construction ghost placement, or a checklist of required materials.

## Known technical context

Factorio mods are written in Lua and have clear lifecycle stages: settings, prototype/data, and runtime/control.

Important constraints and opportunities:

- Factorio mods can define new items, recipes, entities, GUIs, commands, and runtime behavior.
- Runtime Lua can inspect surfaces, entities, inventories, recipes, forces, logistics, construction ghosts, and other game state.
- Factorio 2.0 supports local UDP communication through `helpers.send_udp()` and `helpers.recv_udp()` when launched with `--enable-lua-udp`.
- That UDP communication is localhost-oriented, so for a Kubernetes-hosted dedicated server a sidecar bridge in the same pod is a promising architecture.
- RCON plus custom mod commands could be a simpler MVP path.
- Headless servers cannot provide rendered screenshots through `game.take_screenshot()`, so server-side designs should prioritize structured state over vision.
- Blueprint import/export and ghost placement are plausible interaction mechanisms.

These notes are context only. Competing designs do not need to follow a predetermined architecture.

## Design space to explore

Please propose your own solution for:

- What exactly is the in-game Cogigator object?
- How does the player craft, place, configure, upgrade, or power it?
- What area does it observe, and how is that area visualized?
- What data should be exposed to the assistant?
- How should the assistant communicate with the player?
- What actions should be allowed automatically, require approval, or be forbidden?
- How should multiple Cogigators coordinate?
- How should this work for a local game versus a Kubernetes-hosted server?
- What should the first MVP prove?
- What should be deferred until later?

Avoid assuming there is only one correct answer. The goal is to produce a compelling concept and feasible implementation direction.

## Safety and permissions philosophy

The assistant should be helpful without becoming destructive or overpowered by default.

Consider permissions such as:

- read-only advisor mode
- blueprint suggestion mode
- ghost placement with confirmation
- deconstruction planning with confirmation
- admin/cheat/debug mode, explicitly opt-in only

The player should remain in control. The system should make it clear what the assistant can see and what it is allowed to do.

## Suggested deliverables for competing designs

Each model should produce a design proposal covering:

1. Product fantasy and player story
2. Core gameplay loop
3. In-game entities/items/progression
4. Assistant capabilities and limits
5. Data model at a high level
6. Local-game architecture
7. Dedicated-server/Kubernetes architecture
8. MVP plan
9. Risks and open questions
10. Distinctive ideas that make the concept memorable

## Non-goals for the first concept pass

Do not write full implementation code yet.

Do not over-specify every API field or protocol message.

Do not assume the assistant should directly place real entities or bypass normal construction unless the player explicitly enables a cheat/admin mode.

Do not design a generic chat overlay only. The concept should feel grounded in Factorio and in the physical Cogigator structures.
