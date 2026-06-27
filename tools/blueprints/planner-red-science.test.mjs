import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { buildRedScienceTile } from './planner-red-science.mjs';
import { DIRECTION, validateBlueprintSemantics } from './factorio-model.mjs';

describe('red science deterministic planner', () => {
  it('builds a semantically valid west-side vertical tile', () => {
    const result = buildRedScienceTile();
    assert.equal(result.status, 'valid');
    assert.equal(result.validation.ok, true);
    assert.equal(result.footprint.width, 9);
    assert.equal(result.footprint.height, 7);
    assert.match(result.blueprintString, /^0/);
  });

  it('rejects placements that collide with blocked surface tiles', () => {
    const result = buildRedScienceTile({}, { source: 'test', blockedTiles: [{ x: 2, y: 0 }] });
    assert.equal(result.status, 'no-valid-candidate');
    assert.match(result.candidates[0].validation.errors.join('\n'), /blocked surface tile 2,0/);
  });

  it('semantic validator catches reversed inserter intent', () => {
    const result = buildRedScienceTile();
    const bp = structuredClone(result.blueprint);
    const inputInserter = bp.blueprint.entities.find((entity) => entity.name === 'stack-inserter');
    inputInserter.direction = DIRECTION.west;
    const validation = validateBlueprintSemantics({
      blueprint: bp,
      inserterRoles: result.validationInput?.inserterRoles ?? [{ entityNumber: inputInserter.entity_number, kind: 'input' }],
      beltPorts: result.io.ports,
      expectedRecipe: 'automation-science-pack',
    });
    assert.equal(validation.ok, false);
    assert.match(validation.errors.join('\n'), /input inserter/);
  });
});
