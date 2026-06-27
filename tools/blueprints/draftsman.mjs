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

const command = process.argv[2] ?? 'help';
if (command === 'red-science-same-side') {
  const result = redScienceSameSide();
  console.log(JSON.stringify(result, null, 2));
} else if (command === 'decode') {
  console.log(JSON.stringify(decodeBlueprint(process.argv[3]), null, 2));
} else {
  console.error('Usage: node tools/blueprints/draftsman.mjs red-science-same-side');
  process.exit(command === 'help' ? 0 : 1);
}
