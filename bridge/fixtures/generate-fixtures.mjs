import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const EXPERIMENT_ID = "industrial-cognition-ab";
const SCHEMA_VERSION = "cogigator.snapshot.v1";
const SERVER_TIME = "2026-06-26T00:00:00Z";
const REQUEST_ID = "00000000-0000-0000-0000-000000000000";

const variants = {
  "cognition-flow": {
    experimentId: EXPERIMENT_ID,
    variantId: "cognition-flow",
    variantLetter: "A",
    variantLabel: "Sightline + Cognition Flow",
    inspiredBy: "claude-opus-4-8",
    stationKind: "core",
    stationLabel: "Cogigator Core",
    capacityKeys: ["sightline", "cognitionFlow", "cognitionBuffer", "memory"],
    degradationFlags: ["overloaded"],
    tagline: "Two scarcities: where it can look, and how hard it can think."
  },
  "capacity-vector": {
    experimentId: EXPERIMENT_ID,
    variantId: "capacity-vector",
    variantLetter: "B",
    variantLabel: "Field Station + Capacity Vector",
    inspiredBy: "gpt-5.5",
    stationKind: "field-station",
    stationLabel: "Cogigator Field Station",
    capacityKeys: ["scan", "attention", "memory", "planning"],
    degradationFlags: [],
    tagline: "A bounded field station that spends scan, attention, memory, and planning capacity."
  }
};

const capacityTemplates = {
  "cognition-flow": {
    normal: [
      cap("sightline", "Sightline", 1024, 1024, "tiles^2", true, false, "Entire worksite is visible."),
      cap("cognitionFlow", "Cognition Flow", 24, 20, "cog/min", true, false, "Flow meets deterministic report demand."),
      cap("cognitionBuffer", "Cognition Buffer", 80, 60, "cog", true, false, "Buffer has enough reserve for this report."),
      cap("memory", "Memory", 8, 6, "units", true, false, "Recent observations are retained.")
    ],
    degraded: [
      cap("sightline", "Sightline", 1024, 1024, "tiles^2", true, false, "Entire worksite is visible."),
      cap("cognitionFlow", "Cognition Flow", 8, 20, "cog/min", false, true, "Build more cognition production; flow is below analysis demand."),
      cap("cognitionBuffer", "Cognition Buffer", 4, 60, "cog", false, true, "Memory banks are nearly empty."),
      cap("memory", "Memory", 3, 6, "units", false, false, "Short history limits confidence.")
    ],
    dense: [
      cap("sightline", "Sightline", 1024, 1600, "tiles^2", false, true, "Dense cell exceeds current sightline coverage."),
      cap("cognitionFlow", "Cognition Flow", 18, 28, "cog/min", false, true, "Report cadence slowed by high entity count."),
      cap("cognitionBuffer", "Cognition Buffer", 22, 60, "cog", false, false, "Reserve was spent on capped entity sampling."),
      cap("memory", "Memory", 8, 6, "units", true, false, "History remains available.")
    ]
  },
  "capacity-vector": {
    normal: [
      cap("scan", "Scan", 1024, 1024, "tiles^2", true, false, "Scan budget covers the worksite."),
      cap("attention", "Attention", 3, 2, "slots", true, false, "One station slot remains free."),
      cap("memory", "Memory", 8, 6, "units", true, false, "Recent observations are retained."),
      cap("planning", "Planning", 1, 1, "bool", true, false, "Planning gate is enabled for read-only advice.")
    ],
    degraded: [
      cap("scan", "Scan", 512, 1024, "tiles^2", false, true, "Increase scan capacity or shrink the watched worksite."),
      cap("attention", "Attention", 1, 2, "slots", false, true, "Too many watches are competing for attention."),
      cap("memory", "Memory", 3, 6, "units", false, false, "Short history limits confidence."),
      cap("planning", "Planning", 0, 1, "bool", false, false, "Planning is disabled while the station is under capacity.")
    ],
    dense: [
      cap("scan", "Scan", 1024, 1600, "tiles^2", false, true, "Dense cell exceeds scan budget."),
      cap("attention", "Attention", 1, 3, "slots", false, true, "Attention is capped while sampling the dense cell."),
      cap("memory", "Memory", 8, 6, "units", true, false, "History remains available."),
      cap("planning", "Planning", 1, 1, "bool", true, false, "Planning gate remains available.")
    ]
  }
};

const scenarios = {
  "starved-assembler": {
    tick: 123456,
    worksite: worksite(0, 0, 32, 32),
    power: { satisfaction: 1, demandKw: 680, supplyKw: 680, state: "ok" },
    entities: {
      totalCount: 18,
      byType: { "assembling-machine": 2, "transport-belt": 8, inserter: 6, "electric-pole": 2 },
      representative: [
        machine(101, "assembling-machine-2", "assembling-machine", "iron-gear-wheel", "item-ingredient-shortage", 6, 8, [{ item: "iron-plate", count: 0 }], [{ item: "iron-gear-wheel", count: 0 }], [], "working"),
        belt(112, "transport-belt", 5, 8, "empty")
      ]
    },
    findings: [
      finding("input-starved", "error", 101, "assembling-machine-2", "Assembler starved: input iron-plate empty.", { item: "iron-plate", count: 0 }),
      finding("belt-starved", "warning", 112, "transport-belt", "Input belt is empty upstream of the assembler.", { item: "iron-plate", beltItems: 0 })
    ],
    expectedDiagnosis: [
      diagnosis("input-starved", "Gear assembler starved: no iron-plate reaches the input belt.", true),
      diagnosis("belt-starved", "Upstream belt segment is empty, confirming the missing feed.", false)
    ]
  },
  "blocked-output": {
    tick: 124800,
    worksite: worksite(32, 0, 64, 32),
    power: { satisfaction: 1, demandKw: 740, supplyKw: 740, state: "ok" },
    entities: {
      totalCount: 22,
      byType: { "assembling-machine": 2, "transport-belt": 10, inserter: 8, chest: 2 },
      representative: [
        machine(201, "assembling-machine-2", "assembling-machine", "copper-cable", "full-output", 40, 8, [{ item: "copper-plate", count: 20 }], [{ item: "copper-cable", count: 100 }], [], "working"),
        belt(214, "transport-belt", 42, 8, "backed-up")
      ]
    },
    findings: [
      finding("output-blocked", "error", 201, "assembling-machine-2", "Assembler output full: copper-cable cannot leave.", { item: "copper-cable", outputCount: 100 }),
      finding("belt-backed-up", "warning", 214, "transport-belt", "Output belt is saturated after the assembler.", { item: "copper-cable", beltItems: 8 })
    ],
    expectedDiagnosis: [
      diagnosis("output-blocked", "Copper cable assembler is stopped because product cannot leave.", true),
      diagnosis("belt-backed-up", "Downstream belt saturation is the visible output blockage.", false)
    ]
  },
  "missing-fluid": {
    tick: 126000,
    worksite: worksite(0, 32, 32, 64),
    power: { satisfaction: 1, demandKw: 920, supplyKw: 920, state: "ok" },
    entities: {
      totalCount: 20,
      byType: { "assembling-machine": 1, pipe: 9, "pipe-to-ground": 2, inserter: 4, "transport-belt": 4 },
      representative: [
        machine(301, "assembling-machine-2", "assembling-machine", "sulfur", "fluid-ingredient-shortage", 9, 41, [{ item: "petroleum-gas", count: 0 }, { item: "water", count: 0 }], [{ item: "sulfur", count: 0 }], [{ fluid: "petroleum-gas", amount: 0 }, { fluid: "water", amount: 0 }], "working"),
        pipe(309, "pipe", 8, 41, "empty", "petroleum-gas", 0)
      ]
    },
    findings: [
      finding("missing-fluid", "error", 301, "assembling-machine-2", "Sulfur machine missing petroleum-gas fluid input.", { fluid: "petroleum-gas", amount: 0 })
    ],
    expectedDiagnosis: [
      diagnosis("missing-fluid", "Sulfur production is waiting on petroleum-gas; connect or fill the fluid line.", true)
    ]
  },
  "low-power": {
    tick: 127200,
    worksite: worksite(32, 32, 64, 64),
    power: { satisfaction: 0.42, demandKw: 1200, supplyKw: 504, state: "low" },
    entities: {
      totalCount: 26,
      byType: { "assembling-machine": 4, inserter: 10, "transport-belt": 8, "electric-pole": 4 },
      representative: [
        machine(401, "assembling-machine-2", "assembling-machine", "electronic-circuit", "low-power", 43, 45, [{ item: "iron-plate", count: 10 }, { item: "copper-cable", count: 12 }], [{ item: "electronic-circuit", count: 0 }], [], "low-power"),
        entity(416, "inserter", "inserter", "low-power", 42, 45, "low-power")
      ]
    },
    findings: [
      finding("low-power", "error", null, null, "Electric network under-supplied: satisfaction is 42%.", { satisfaction: 0.42, demandKw: 1200, supplyKw: 504 })
    ],
    expectedDiagnosis: [
      diagnosis("low-power", "Power supply meets only 42% of demand; add generation or reduce load.", true)
    ]
  },
  "under-computed": {
    tick: 128400,
    worksite: worksite(64, 0, 96, 32),
    power: { satisfaction: 1, demandKw: 640, supplyKw: 640, state: "ok" },
    capacityProfile: "degraded",
    entities: {
      totalCount: 16,
      byType: { "assembling-machine": 2, "transport-belt": 8, inserter: 4, "electric-pole": 2 },
      representative: [
        machine(501, "assembling-machine-2", "assembling-machine", "transport-belt", "working", 72, 8, [{ item: "iron-plate", count: 30 }, { item: "iron-gear-wheel", count: 10 }], [{ item: "transport-belt", count: 4 }], [], "working")
      ]
    },
    findings: [
      finding("under-computed", "warning", null, null, "Station cognition capacity below deterministic report demand.", { degraded: true })
    ],
    expectedDiagnosis: [
      diagnosis("under-computed", "Factory symptoms are clear enough, but station capacity is degraded and limits explanation depth.", true)
    ]
  },
  "dense-cell-truncated": {
    tick: 129600,
    worksite: worksite(64, 32, 104, 72),
    power: { satisfaction: 0.88, demandKw: 2800, supplyKw: 2464, state: "low" },
    capacityProfile: "dense",
    omitted: { entityCount: 55, reason: "entity-cap", caps: { representative: 8, byType: 64 } },
    entities: {
      totalCount: 142,
      byType: { "assembling-machine": 34, "transport-belt": 58, inserter: 36, "electric-pole": 10, pipe: 4 },
      representative: [
        machine(601, "assembling-machine-2", "assembling-machine", "iron-gear-wheel", "item-ingredient-shortage", 70, 40, [{ item: "iron-plate", count: 0 }], [{ item: "iron-gear-wheel", count: 0 }], [], "working"),
        machine(602, "assembling-machine-2", "assembling-machine", "copper-cable", "full-output", 74, 40, [{ item: "copper-plate", count: 30 }], [{ item: "copper-cable", count: 100 }], [], "working"),
        machine(603, "assembling-machine-2", "assembling-machine", "electronic-circuit", "low-power", 78, 40, [{ item: "iron-plate", count: 8 }, { item: "copper-cable", count: 4 }], [{ item: "electronic-circuit", count: 0 }], [], "low-power"),
        belt(621, "transport-belt", 69, 40, "empty"),
        belt(622, "transport-belt", 75, 40, "backed-up"),
        entity(640, "inserter", "inserter", "waiting-for-space-in-destination", 76, 40, "working"),
        pipe(650, "pipe", 82, 40, "empty", "water", 0),
        entity(660, "small-electric-pole", "electric-pole", "working", 80, 42, "working")
      ]
    },
    findings: [
      finding("input-starved", "error", 601, "assembling-machine-2", "Dense cell sample includes a gear assembler with no iron input.", { item: "iron-plate", count: 0 }),
      finding("output-blocked", "error", 602, "assembling-machine-2", "Dense cell sample includes a copper-cable assembler with full output.", { item: "copper-cable", outputCount: 100 }),
      finding("low-power", "warning", null, null, "Dense cell network is under-supplied at 88% satisfaction.", { satisfaction: 0.88, demandKw: 2800, supplyKw: 2464 }),
      finding("under-computed", "warning", null, null, "Dense cell exceeded cognition/report caps; representative list is truncated.", { omittedEntityCount: 55 })
    ],
    expectedDiagnosis: [
      diagnosis("input-starved", "Primary sampled fault: one gear assembler has no iron input.", true),
      diagnosis("output-blocked", "Another sampled fault is copper cable output blockage.", false),
      diagnosis("under-computed", "Report is intentionally truncated because the cell exceeded entity/report caps.", false)
    ]
  }
};

for (const [scenarioId, scenario] of Object.entries(scenarios)) {
  for (const variantId of Object.keys(variants)) {
    const file = join("bridge", "fixtures", variantId, `${scenarioId}.json`);
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, `${JSON.stringify(snapshot(scenarioId, variantId, scenario), null, 2)}\n`);
  }
}

writeFileSync(
  join("bridge", "fixtures", "index.json"),
  `${JSON.stringify({
    experimentId: EXPERIMENT_ID,
    schemaVersion: SCHEMA_VERSION,
    fixtureLayout: "bridge/fixtures/<variantId>/<scenarioId>.json",
    variants: Object.keys(variants),
    scenarios: Object.keys(scenarios)
  }, null, 2)}\n`
);

function snapshot(scenarioId, variantId, scenario) {
  const variant = variants[variantId];
  const omitted = scenario.omitted ?? { entityCount: 0, reason: "none", caps: { representative: 8, byType: 64 } };

  return {
    schemaVersion: SCHEMA_VERSION,
    experimentId: EXPERIMENT_ID,
    scenarioId,
    variant,
    requestId: REQUEST_ID,
    serverTime: SERVER_TIME,
    factorio: { version: "2.0.x", save: "spike-fixture" },
    station: {
      stationId: variant.stationKind === "core" ? "core-1" : "field-station-1",
      stationKind: variant.stationKind,
      stationLabel: variant.stationLabel,
      permissionMode: "read-only-advisor",
      transportHealth: omitted.reason === "none" ? "ok" : "degraded",
      status: stationStatus(variantId, scenario.capacityProfile, omitted)
    },
    worksite: scenario.worksite,
    tick: scenario.tick,
    cognition: cognition(variantId, scenario.capacityProfile ?? "normal"),
    power: scenario.power,
    entities: scenario.entities,
    findings: scenario.findings.map((item) => ({ ...item, tick: scenario.tick })),
    omitted,
    truncated: omitted.reason !== "none",
    expectedDiagnosis: scenario.expectedDiagnosis
  };
}

function cognition(variantId, profile) {
  const capacities = capacityTemplates[variantId][profile];
  const degraded = capacities.some((item) => !item.satisfied);
  const overloaded = variantId === "cognition-flow" && profile === "degraded";

  return {
    model: variantId,
    capacities,
    degradation: {
      degraded: degraded || overloaded,
      level: profile === "normal" ? "none" : profile === "degraded" ? "severe" : "partial",
      flags: variantId === "cognition-flow" ? { overloaded } : {},
      reasons: profile === "normal" ? [] : reasonsFor(variantId, profile),
      effects: profile === "normal" ? [] : effectsFor(profile)
    }
  };
}

function stationStatus(variantId, profile, omitted) {
  if (profile === "degraded" && variantId === "cognition-flow") return "overloaded";
  if (omitted.reason !== "none") return "live";
  return "live";
}

function reasonsFor(variantId, profile) {
  if (profile === "dense") return ["entity-cap", `${variantId}-capacity-below-dense-cell-demand`];
  return variantId === "cognition-flow"
    ? ["cognition-flow-below-demand", "cognition-buffer-empty"]
    : ["scan-below-demand", "attention-slots-exhausted", "planning-disabled"];
}

function effectsFor(profile) {
  if (profile === "dense") return ["report-cadence-slowed", "analysis-depth-reduced", "worksite-shrunk"];
  return ["report-cadence-slowed", "analysis-depth-reduced", "deterministic-only"];
}

function worksite(left, top, right, bottom) {
  return { surface: "nauvis", bounds: { left, top, right, bottom }, width: right - left, height: bottom - top };
}

function cap(key, label, value, limit, unit, satisfied, bottleneck, note) {
  return { key, label, value, limit, unit, satisfied, bottleneck, note };
}

function finding(code, severity, subjectUnitNumber, subjectName, message, evidence) {
  return { code, severity, subjectUnitNumber, subjectName, message, evidence };
}

function diagnosis(findingCode, summary, primary) {
  return { findingCode, summary, primary };
}

function entity(unitNumber, name, type, status, x, y, powerState) {
  return { unitNumber, name, type, status, position: { x, y }, powerState };
}

function machine(unitNumber, name, type, recipe, status, x, y, inputs, outputs, fluids, powerState) {
  return { ...entity(unitNumber, name, type, status, x, y, powerState), recipe, inputs, outputs, fluids };
}

function belt(unitNumber, name, x, y, beltState) {
  return {
    ...entity(unitNumber, name, "transport-belt", beltState, x, y, "working"),
    inputs: [],
    outputs: [],
    fluids: []
  };
}

function pipe(unitNumber, name, x, y, status, fluid, amount) {
  return {
    ...entity(unitNumber, name, "pipe", status, x, y, "working"),
    fluids: [{ fluid, amount }]
  };
}
