#!/usr/bin/env node
import { deflateSync, inflateSync } from 'node:zlib';

function encodeBlueprint(blueprint) {
  return `0${deflateSync(Buffer.from(JSON.stringify(blueprint))).toString('base64')}`;
}

function decodeBlueprint(str) {
  return JSON.parse(inflateSync(Buffer.from(str.slice(1), 'base64')).toString('utf8'));
}

let entityNumber = 1;
function entity(name, x, y, extra = {}) {
  return { entity_number: entityNumber++, name, position: { x, y }, ...extra };
}

function redScienceSameSide() {
  entityNumber = 1;
  const entities = [];
  const assemblerYs = [0, 3, 6, 9];

  // Coordinate contract:
  // west side I/O, vertical bus:
  //   x=-4 output science belt, southbound
  //   x=-2 input mixed belt, southbound (copper plate + iron gear wheels)
  // Assemblers sit at x=1.5. Inserters sit between belts and assemblers.
  for (const y of assemblerYs) {
    entities.push(entity('assembling-machine-1', 1.5, y, { recipe: 'automation-science-pack' }));
    // Input inserter: pickup from mixed input belt at x=-2, drop into assembler.
    entities.push(entity('long-handed-inserter', -0.5, y - 1, { direction: 2 }));
    // Output inserter: pickup from assembler, drop to output belt at x=-4.
    entities.push(entity('long-handed-inserter', -0.5, y + 1, { direction: 6 }));
  }

  for (let y = -2; y <= 11; y++) {
    entities.push(entity('transport-belt', -2, y, { direction: 4 }));
    entities.push(entity('transport-belt', -4, y, { direction: 4 }));
  }

  // Power/lights on east side.
  for (const y of [-1, 4, 9]) entities.push(entity('small-electric-pole', 4, y));
  for (const y of [1, 6]) entities.push(entity('small-lamp', 5, y));

  const blueprint = {
    blueprint: {
      item: 'blueprint',
      label: 'Red science same-side I/O v2',
      description: 'Proposal-only compact red science block. West side I/O: x=-2 mixed input belt, x=-4 science output belt. Verify inserter reach/orientation after import.',
      icons: [{ signal: { type: 'item', name: 'automation-science-pack' }, index: 1 }],
      entities,
      version: 562949954142208,
    },
  };

  return {
    name: 'red-science-same-side',
    footprint: { left: -4, top: -2, right: 5, bottom: 11, width: 10, height: 14 },
    io: {
      side: 'west',
      input: 'x=-2 vertical belt, copper plates + iron gear wheels on lanes',
      output: 'x=-4 vertical belt, automation science packs',
    },
    validation: validateRedScience(blueprint),
    blueprint,
    blueprintString: encodeBlueprint(blueprint),
  };
}

function validateRedScience(bp) {
  const ents = bp.blueprint.entities;
  const assemblers = ents.filter(e => e.name === 'assembling-machine-1');
  const belts = ents.filter(e => e.name === 'transport-belt');
  const poles = ents.filter(e => e.name === 'small-electric-pole');
  const lamps = ents.filter(e => e.name === 'small-lamp');
  const longInserters = ents.filter(e => e.name === 'long-handed-inserter');
  const errors = [];
  if (assemblers.length !== 4) errors.push(`expected 4 assemblers, got ${assemblers.length}`);
  if (!assemblers.every(e => e.recipe === 'automation-science-pack')) errors.push('not every assembler makes automation-science-pack');
  if (belts.length !== 28) errors.push(`expected 28 belts, got ${belts.length}`);
  if (!belts.every(e => e.direction === 4)) errors.push('all belts should run south');
  if (longInserters.length !== 8) errors.push(`expected 8 long-handed inserters, got ${longInserters.length}`);
  if (poles.length < 3) errors.push('expected at least 3 poles');
  if (lamps.length < 2) errors.push('expected at least 2 lamps');
  return { ok: errors.length === 0, errors };
}

function redScienceEndgameSameSideC() {
  entityNumber = 1;
  const entities = [];
  const assemblerYs = [0, 4, 8, 12];

  // Concept C: clean vertical tile, all I/O on west side.
  //   x=-2 output science belt, northbound
  //   x=-1 input mixed belt, southbound (copper plate + iron gear wheels)
  //   x=0 inserter column
  //   x=2 assembler column
  //   x=5 power/light column
  for (const y of assemblerYs) {
    entities.push(entity('assembling-machine-3', 2, y, { recipe: 'automation-science-pack' }));
    entities.push(entity('stack-inserter', 0, y - 1, { direction: 2 }));
    entities.push(entity('long-handed-inserter', 0, y + 1, { direction: 6 }));
  }

  for (let y = -2; y <= 14; y++) {
    entities.push(entity('express-transport-belt', -1, y, { direction: 4 }));
    entities.push(entity('express-transport-belt', -2, y, { direction: 0 }));
  }

  entities.push(entity('substation', 5.5, 6.5));
  for (const y of [1, 6, 11]) entities.push(entity('small-lamp', 5, y));

  const blueprint = {
    blueprint: {
      item: 'blueprint',
      label: 'Endgame red science C - same-side I/O',
      description: 'Proposal-only. Concept C: west-side I/O. x=-1 express input belt carries copper plates + iron gear wheels. x=-2 express output belt carries automation science packs. Tile vertically by overlapping/continuing belts.',
      icons: [{ signal: { type: 'item', name: 'automation-science-pack' }, index: 1 }],
      entities,
      version: 562949954142208,
    },
  };

  return {
    name: 'red-science-endgame-same-side-c',
    footprint: { left: -2, top: -2, right: 6, bottom: 14, width: 9, height: 17 },
    io: {
      side: 'west',
      input: 'x=-1 vertical express belt southbound; copper plates + iron gear wheels lane-balanced',
      output: 'x=-2 vertical express belt northbound; automation science packs',
      tileDirection: 'vertical; continue/overlap the two west-side belts',
    },
    preview: [
      'west side',
      'x=-2 output ↑ | x=-1 input ↓ | x=0 inserters | x=2 assemblers | x=5 power/lights',
      'repeat rows at y=0,4,8,12',
    ],
    validation: validateRedScienceEndgameC(blueprint),
    blueprint,
    blueprintString: encodeBlueprint(blueprint),
  };
}

function validateRedScienceEndgameC(bp) {
  const ents = bp.blueprint.entities;
  const assemblers = ents.filter(e => e.name === 'assembling-machine-3');
  const belts = ents.filter(e => e.name === 'express-transport-belt');
  const substations = ents.filter(e => e.name === 'substation');
  const lamps = ents.filter(e => e.name === 'small-lamp');
  const stackInserters = ents.filter(e => e.name === 'stack-inserter');
  const longInserters = ents.filter(e => e.name === 'long-handed-inserter');
  const errors = [];
  if (assemblers.length !== 4) errors.push(`expected 4 assemblers, got ${assemblers.length}`);
  if (!assemblers.every(e => e.recipe === 'automation-science-pack')) errors.push('not every assembler makes automation-science-pack');
  if (belts.length !== 34) errors.push(`expected 34 express belts, got ${belts.length}`);
  if (stackInserters.length !== 4) errors.push(`expected 4 stack inserters, got ${stackInserters.length}`);
  if (!stackInserters.every(e => e.direction === 2)) errors.push('stack inserters should face east into assemblers');
  if (longInserters.length !== 4) errors.push(`expected 4 long-handed inserters, got ${longInserters.length}`);
  if (!longInserters.every(e => e.direction === 6)) errors.push('long-handed inserters should face west to output belt');
  if (substations.length !== 1) errors.push(`expected 1 substation, got ${substations.length}`);
  if (lamps.length !== 3) errors.push(`expected 3 lamps, got ${lamps.length}`);
  return { ok: errors.length === 0, errors };
}

function redScienceEndgameSameSideC3Small() {
  entityNumber = 1;
  const entities = [];
  const assemblerYs = [0, 3];

  // Concept C3-small: compact 2-assembler vertical tile, all I/O on west side.
  //   x=-2 output science belt, northbound
  //   x=-1 input mixed belt, southbound (copper plate + iron gear wheels)
  //   x=0 inserter column
  //   x=2 assembler column (assemblers touch as a compact stack)
  //   x=4/5 power + lights
  for (const y of assemblerYs) {
    entities.push(entity('assembling-machine-3', 2, y, { recipe: 'automation-science-pack' }));
    // Input: pickup from x=-1 input belt, drop into west edge of assembler.
    entities.push(entity('stack-inserter', 0, y - 1, { direction: 2 }));
    // Output: pickup from assembler, long-drop to x=-2 output belt.
    entities.push(entity('long-handed-inserter', 0, y + 1, { direction: 6 }));
  }

  for (let y = -2; y <= 5; y++) {
    entities.push(entity('express-transport-belt', -1, y, { direction: 4 }));
    entities.push(entity('express-transport-belt', -2, y, { direction: 0 }));
  }

  entities.push(entity('substation', 4.5, 1.5));
  entities.push(entity('small-lamp', 5, -1));
  entities.push(entity('small-lamp', 5, 4));

  const blueprint = {
    blueprint: {
      item: 'blueprint',
      label: 'Endgame red science C3 small - same-side I/O',
      description: 'Proposal-only. Compact 2-assembler tile. West side I/O: x=-1 express input belt carries copper plates + iron gear wheels; x=-2 express output belt carries automation science packs. Tile vertically by continuing belts.',
      icons: [{ signal: { type: 'item', name: 'automation-science-pack' }, index: 1 }],
      entities,
      version: 562949954142208,
    },
  };

  return {
    name: 'red-science-endgame-same-side-c3-small',
    footprint: { left: -2, top: -2, right: 5, bottom: 5, width: 8, height: 8 },
    io: {
      side: 'west',
      input: 'x=-1 vertical express belt southbound; copper plates + iron gear wheels lane-balanced',
      output: 'x=-2 vertical express belt northbound; automation science packs',
      tileDirection: 'vertical; continue the two west-side belts between tiles',
    },
    preview: [
      'west side',
      'O I > A',
      'O I < A',
      'O I > A',
      'O I < A',
      'O=output northbound, I=input southbound, A=assembler-3',
    ],
    validation: validateRedScienceEndgameC3Small(blueprint),
    blueprint,
    blueprintString: encodeBlueprint(blueprint),
  };
}

function validateRedScienceEndgameC3Small(bp) {
  const ents = bp.blueprint.entities;
  const assemblers = ents.filter(e => e.name === 'assembling-machine-3');
  const belts = ents.filter(e => e.name === 'express-transport-belt');
  const substations = ents.filter(e => e.name === 'substation');
  const lamps = ents.filter(e => e.name === 'small-lamp');
  const stackInserters = ents.filter(e => e.name === 'stack-inserter');
  const longInserters = ents.filter(e => e.name === 'long-handed-inserter');
  const errors = [];
  if (assemblers.length !== 2) errors.push(`expected 2 assemblers, got ${assemblers.length}`);
  if (!assemblers.every(e => e.recipe === 'automation-science-pack')) errors.push('not every assembler makes automation-science-pack');
  if (belts.length !== 16) errors.push(`expected 16 express belts, got ${belts.length}`);
  if (stackInserters.length !== 2) errors.push(`expected 2 stack inserters, got ${stackInserters.length}`);
  if (!stackInserters.every(e => e.direction === 2)) errors.push('stack inserters should face east into assemblers');
  if (longInserters.length !== 2) errors.push(`expected 2 long-handed inserters, got ${longInserters.length}`);
  if (!longInserters.every(e => e.direction === 6)) errors.push('long-handed inserters should face west to output belt');
  if (substations.length !== 1) errors.push(`expected 1 substation, got ${substations.length}`);
  if (lamps.length !== 2) errors.push(`expected 2 lamps, got ${lamps.length}`);
  return { ok: errors.length === 0, errors };
}

const command = process.argv[2] ?? 'help';
if (command === 'red-science-same-side') {
  const result = redScienceSameSide();
  console.log(JSON.stringify(result, null, 2));
} else if (command === 'red-science-endgame-same-side-c') {
  const result = redScienceEndgameSameSideC();
  console.log(JSON.stringify(result, null, 2));
} else if (command === 'red-science-endgame-same-side-c3-small') {
  const result = redScienceEndgameSameSideC3Small();
  console.log(JSON.stringify(result, null, 2));
} else if (command === 'decode') {
  console.log(JSON.stringify(decodeBlueprint(process.argv[3]), null, 2));
} else {
  console.error('Usage: node tools/blueprints/draftsman.mjs red-science-same-side|red-science-endgame-same-side-c|red-science-endgame-same-side-c3-small');
  process.exit(command === 'help' ? 0 : 1);
}
