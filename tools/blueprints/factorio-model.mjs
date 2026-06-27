import { deflateSync, inflateSync } from 'node:zlib';

export const DIRECTION = Object.freeze({ north: 0, east: 2, south: 4, west: 6 });

export function encodeBlueprint(blueprint) {
  return `0${deflateSync(Buffer.from(JSON.stringify(blueprint))).toString('base64')}`;
}

export function decodeBlueprint(str) {
  return JSON.parse(inflateSync(Buffer.from(str.slice(1), 'base64')).toString('utf8'));
}

export function entityFactory() {
  let entityNumber = 1;
  return (name, x, y, extra = {}) => ({ entity_number: entityNumber++, name, position: { x, y }, ...extra });
}

export function directionVector(direction) {
  if (direction === DIRECTION.north) return { x: 0, y: -1 };
  if (direction === DIRECTION.east) return { x: 1, y: 0 };
  if (direction === DIRECTION.south) return { x: 0, y: 1 };
  if (direction === DIRECTION.west) return { x: -1, y: 0 };
  throw new Error(`unsupported direction: ${direction}`);
}

export function tileKey(x, y) {
  return `${x},${y}`;
}

export function posKey(pos) {
  return tileKey(pos.x, pos.y);
}

export function beltOutputTile(belt) {
  const v = directionVector(belt.direction ?? DIRECTION.north);
  return { x: belt.position.x + v.x, y: belt.position.y + v.y };
}

export function beltInputTile(belt) {
  const v = directionVector(belt.direction ?? DIRECTION.north);
  return { x: belt.position.x - v.x, y: belt.position.y - v.y };
}

export function isBelt(entity) {
  return ['transport-belt', 'fast-transport-belt', 'express-transport-belt'].includes(entity.name);
}

export function isInserter(entity) {
  return ['inserter', 'fast-inserter', 'stack-inserter', 'long-handed-inserter', 'bulk-inserter'].includes(entity.name);
}

export function isAssembler(entity) {
  return ['assembling-machine-1', 'assembling-machine-2', 'assembling-machine-3'].includes(entity.name);
}

export function entityBox(entity) {
  if (isAssembler(entity)) return centeredBox(entity.position, 3, 3);
  if (entity.name === 'substation') return centeredBox(entity.position, 2, 2);
  return centeredBox(entity.position, 1, 1);
}

function centeredBox(pos, width, height) {
  return {
    left: pos.x - width / 2,
    right: pos.x + width / 2,
    top: pos.y - height / 2,
    bottom: pos.y + height / 2,
  };
}

export function pointInBox(point, box) {
  return point.x > box.left && point.x < box.right && point.y > box.top && point.y < box.bottom;
}

export function pointInsideEntity(point, entity) {
  return pointInBox(point, entityBox(entity));
}

export function inserterReach(entity) {
  // Vanilla normal/fast/stack pickup is one tile behind and drop is one tile ahead.
  // Vanilla long-handed pickup/drop are two tiles away.
  return entity.name === 'long-handed-inserter' ? 2 : 1;
}

export function inserterPickupDrop(entity) {
  const v = directionVector(entity.direction ?? DIRECTION.north);
  const reach = inserterReach(entity);
  return {
    pickup: { x: entity.position.x - v.x * reach, y: entity.position.y - v.y * reach },
    drop: { x: entity.position.x + v.x * reach, y: entity.position.y + v.y * reach },
  };
}

export function validateBeltConnectivity(entities, ports = {}) {
  const belts = entities.filter(isBelt);
  const beltByTile = new Map(belts.map((belt) => [posKey(belt.position), belt]));
  const errors = [];
  const externalInputs = new Set((ports.externalInputs ?? []).map(posKey));
  const externalOutputs = new Set((ports.externalOutputs ?? []).map(posKey));

  for (const belt of belts) {
    const inTile = beltInputTile(belt);
    const outTile = beltOutputTile(belt);
    const hasUpstream = beltByTile.has(posKey(inTile)) || externalInputs.has(posKey(belt.position));
    const hasDownstream = beltByTile.has(posKey(outTile)) || externalOutputs.has(posKey(belt.position));
    if (!hasUpstream) errors.push(`belt ${belt.entity_number} at ${posKey(belt.position)} has no upstream belt or external input`);
    if (!hasDownstream) errors.push(`belt ${belt.entity_number} at ${posKey(belt.position)} has no downstream belt or external output`);
  }

  return { ok: errors.length === 0, errors };
}

export function validateInserterConnectivity(entities, roles = []) {
  const errors = [];
  const roleByEntityNumber = new Map(roles.map((role) => [role.entityNumber, role]));
  const belts = entities.filter(isBelt);
  const assemblers = entities.filter(isAssembler);

  for (const inserter of entities.filter(isInserter)) {
    const role = roleByEntityNumber.get(inserter.entity_number);
    const { pickup, drop } = inserterPickupDrop(inserter);
    const pickupBelt = belts.find((belt) => posKey(belt.position) === posKey(pickup));
    const dropBelt = belts.find((belt) => posKey(belt.position) === posKey(drop));
    const pickupAssembler = assemblers.find((assembler) => pointInsideEntity(pickup, assembler));
    const dropAssembler = assemblers.find((assembler) => pointInsideEntity(drop, assembler));

    if (!role) {
      if (!pickupBelt && !pickupAssembler) errors.push(`inserter ${inserter.entity_number} pickup ${posKey(pickup)} reaches nothing`);
      if (!dropBelt && !dropAssembler) errors.push(`inserter ${inserter.entity_number} drop ${posKey(drop)} reaches nothing`);
      continue;
    }

    if (role.kind === 'input') {
      if (!pickupBelt) errors.push(`input inserter ${inserter.entity_number} does not pick from a belt; pickup=${posKey(pickup)}`);
      if (!dropAssembler) errors.push(`input inserter ${inserter.entity_number} does not drop into assembler; drop=${posKey(drop)}`);
      if (role.assemblerEntityNumber && dropAssembler?.entity_number !== role.assemblerEntityNumber) {
        errors.push(`input inserter ${inserter.entity_number} drops into assembler ${dropAssembler?.entity_number}, expected ${role.assemblerEntityNumber}`);
      }
    } else if (role.kind === 'output') {
      if (!pickupAssembler) errors.push(`output inserter ${inserter.entity_number} does not pick from assembler; pickup=${posKey(pickup)}`);
      if (!dropBelt) errors.push(`output inserter ${inserter.entity_number} does not drop onto a belt; drop=${posKey(drop)}`);
      if (role.assemblerEntityNumber && pickupAssembler?.entity_number !== role.assemblerEntityNumber) {
        errors.push(`output inserter ${inserter.entity_number} picks from assembler ${pickupAssembler?.entity_number}, expected ${role.assemblerEntityNumber}`);
      }
    }
  }

  return { ok: errors.length === 0, errors };
}

export function validateCollisions(entities, surface = {}) {
  const errors = [];
  const occupiedTiles = new Map();
  const blocked = new Set((surface.blockedTiles ?? []).map((tile) => tileKey(tile.x, tile.y)));

  for (const entity of entities) {
    for (const tile of occupiedTilesForEntity(entity)) {
      const key = tileKey(tile.x, tile.y);
      if (blocked.has(key)) errors.push(`entity ${entity.entity_number} overlaps blocked surface tile ${key}`);
      const prev = occupiedTiles.get(key);
      if (prev) {
        errors.push(`entity ${entity.entity_number} overlaps entity ${prev.entity_number} at tile ${key}`);
      } else {
        occupiedTiles.set(key, entity);
      }
    }
  }
  return { ok: errors.length === 0, errors };
}

function occupiedTilesForEntity(entity) {
  const { x, y } = entity.position;
  if (isAssembler(entity)) return squareTilesAroundCenter(x, y, 3);
  if (entity.name === 'substation') return squareTilesAroundCenter(x, y, 2);
  return [{ x, y }];
}

function squareTilesAroundCenter(cx, cy, size) {
  const firstX = Math.ceil(cx - size / 2);
  const firstY = Math.ceil(cy - size / 2);
  const tiles = [];
  for (let y = firstY; y < firstY + size; y++) {
    for (let x = firstX; x < firstX + size; x++) tiles.push({ x, y });
  }
  return tiles;
}

export function blueprintBounds(entities) {
  const boxes = entities.map(entityBox);
  const left = Math.floor(Math.min(...boxes.map((box) => box.left)));
  const right = Math.ceil(Math.max(...boxes.map((box) => box.right))) - 1;
  const top = Math.floor(Math.min(...boxes.map((box) => box.top)));
  const bottom = Math.ceil(Math.max(...boxes.map((box) => box.bottom))) - 1;
  return { left, top, right, bottom, width: right - left + 1, height: bottom - top + 1 };
}

export function validateBlueprintSemantics({ blueprint, inserterRoles = [], beltPorts = {}, surface = {}, expectedRecipe }) {
  const entities = blueprint.blueprint.entities;
  const errors = [];
  const collisions = validateCollisions(entities, surface);
  const belts = validateBeltConnectivity(entities, beltPorts);
  const inserters = validateInserterConnectivity(entities, inserterRoles);
  const assemblers = entities.filter(isAssembler);
  if (expectedRecipe && !assemblers.every((assembler) => assembler.recipe === expectedRecipe)) {
    errors.push(`not every assembler has recipe ${expectedRecipe}`);
  }
  errors.push(...collisions.errors, ...belts.errors, ...inserters.errors);
  return {
    ok: errors.length === 0,
    errors,
    checks: { collisions, belts, inserters },
  };
}
