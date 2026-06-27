#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
import {
  DIRECTION,
  blueprintBounds,
  encodeBlueprint,
  entityFactory,
  validateBlueprintSemantics,
} from './factorio-model.mjs';

const DEFAULT_REQUIREMENTS = Object.freeze({
  recipe: 'automation-science-pack',
  assembler: 'assembling-machine-3',
  assemblers: 2,
  belt: 'express-transport-belt',
  inputSide: 'west',
  outputSide: 'west',
  tileable: 'vertical',
  includePower: true,
  includeLights: true,
  preferCompact: true,
});

export function buildRedScienceTile(requirements = {}, surface = {}) {
  const req = { ...DEFAULT_REQUIREMENTS, ...requirements };
  if (req.recipe !== 'automation-science-pack') throw new Error('planner-red-science only supports automation-science-pack');
  if (req.inputSide !== 'west' || req.outputSide !== 'west') throw new Error('planner-red-science MVP only supports west-side I/O');
  if (req.tileable !== 'vertical') throw new Error('planner-red-science MVP only supports vertical tiling');

  const candidates = [
    buildCandidate({ req, surface, assemblerCenters: [{ x: 2, y: 0 }, { x: 2, y: 3 }], beltTop: -1, beltBottom: 4 }),
  ];

  const valid = candidates
    .map((candidate) => ({ ...candidate, score: scoreCandidate(candidate) }))
    .filter((candidate) => candidate.validation.ok)
    .sort((a, b) => a.score - b.score);

  if (valid.length === 0) {
    return {
      name: 'red-science-planned-west-io',
      requirements: req,
      surfaceSummary: summarizeSurface(surface),
      status: 'no-valid-candidate',
      candidates: candidates.map(({ blueprintString, ...candidate }) => candidate),
    };
  }

  return valid[0];
}

function buildCandidate({ req, surface, assemblerCenters, beltTop, beltBottom }) {
  const makeEntity = entityFactory();
  const entities = [];
  const inserterRoles = [];

  const inputBeltX = -1;
  const outputBeltX = -2;

  for (let y = beltTop; y <= beltBottom; y++) {
    entities.push(makeEntity(req.belt, inputBeltX, y, { direction: DIRECTION.south }));
    entities.push(makeEntity(req.belt, outputBeltX, y, { direction: DIRECTION.north }));
  }

  for (const center of assemblerCenters) {
    const assembler = makeEntity(req.assembler, center.x, center.y, { recipe: req.recipe });
    entities.push(assembler);

    const inputInserter = makeEntity('stack-inserter', 0, center.y, { direction: DIRECTION.east });
    entities.push(inputInserter);
    inserterRoles.push({ entityNumber: inputInserter.entity_number, kind: 'input', assemblerEntityNumber: assembler.entity_number });

    const outputInserter = makeEntity('long-handed-inserter', 0, center.y + 1, { direction: DIRECTION.west });
    entities.push(outputInserter);
    inserterRoles.push({ entityNumber: outputInserter.entity_number, kind: 'output', assemblerEntityNumber: assembler.entity_number });
  }

  if (req.includePower) entities.push(makeEntity('substation', 5, 1.5));
  if (req.includeLights) {
    entities.push(makeEntity('small-lamp', 5, -1));
    entities.push(makeEntity('small-lamp', 5, 4));
  }

  const blueprint = {
    blueprint: {
      item: 'blueprint',
      label: 'Planned red science: semantic west I/O tile',
      description: [
        'Cogigator proposal only. Deterministically planned and semantically validated for belt connectivity and inserter pickup/drop.',
        'West side I/O: x=-1 input belt southbound carries copper plates + iron gear wheels; x=-2 output belt northbound carries automation science packs.',
      ].join(' '),
      icons: [{ signal: { type: 'item', name: 'automation-science-pack' }, index: 1 }],
      entities,
      version: 562949954142208,
    },
  };

  const beltPorts = {
    externalInputs: [
      { x: inputBeltX, y: beltTop },
      { x: outputBeltX, y: beltBottom },
    ],
    externalOutputs: [
      { x: inputBeltX, y: beltBottom },
      { x: outputBeltX, y: beltTop },
    ],
  };

  const validation = validateBlueprintSemantics({
    blueprint,
    inserterRoles,
    beltPorts,
    surface,
    expectedRecipe: req.recipe,
  });

  return {
    name: 'red-science-planned-west-io',
    status: validation.ok ? 'valid' : 'invalid',
    requirements: req,
    surfaceSummary: summarizeSurface(surface),
    footprint: blueprintBounds(entities),
    io: {
      side: 'west',
      input: `x=${inputBeltX} vertical ${req.belt} southbound; copper plates + iron gear wheels lane-balanced`,
      output: `x=${outputBeltX} vertical ${req.belt} northbound; automation science packs`,
      tileDirection: 'vertical; continue the two west-side belts across tile edges',
      ports: beltPorts,
    },
    preview: [
      'west side, semantic plan',
      'O I > [A]',
      'O I < [A]',
      'O I > [A]',
      'O I < [A]',
      'O=output northbound, I=input southbound, >=input inserter, <=output long inserter',
    ],
    validation,
    blueprint,
    blueprintString: encodeBlueprint(blueprint),
  };
}

function scoreCandidate(candidate) {
  const { width, height } = candidate.footprint;
  return width * height + candidate.blueprint.blueprint.entities.length;
}

function summarizeSurface(surface) {
  return {
    source: surface.source ?? 'synthetic-empty-surface',
    blockedTiles: surface.blockedTiles?.length ?? 0,
  };
}

async function loadJsonArg(flag) {
  const index = process.argv.indexOf(flag);
  if (index === -1) return undefined;
  const file = process.argv[index + 1];
  if (!file) throw new Error(`missing value for ${flag}`);
  return JSON.parse(await readFile(file, 'utf8'));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const snapshot = await loadJsonArg('--snapshot');
  const surface = (await loadJsonArg('--surface')) ?? snapshot?.surfaceScan ?? {};
  const requirements = await loadJsonArg('--requirements') ?? {};
  const result = buildRedScienceTile(requirements, surface);
  console.log(JSON.stringify(result, null, 2));
  if (result.status !== 'valid') process.exitCode = 2;
}
