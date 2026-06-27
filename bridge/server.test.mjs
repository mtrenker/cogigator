import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { inflateSync } from 'node:zlib';
import { createBridgeServer, loadFixtureIndex } from './server.mjs';

let server;
let baseUrl;

async function requestJson(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, options);
  const body = await response.json();
  return { response, body };
}

describe('local bridge stub', () => {
  before(async () => {
    server = createBridgeServer();
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(0, '127.0.0.1', () => {
        server.off('error', reject);
        const address = server.address();
        baseUrl = `http://${address.address}:${address.port}`;
        resolve();
      });
    });
  });

  after(async () => {
    await new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  });

  it('reports health and version metadata', async () => {
    const health = await requestJson('/health');
    assert.equal(health.response.status, 200);
    assert.equal(health.body.schemaVersion, 'cogigator.bridge.v1');
    assert.equal(health.body.status, 'ok');
    assert.ok(health.body.requestId);

    const version = await requestJson('/version');
    assert.equal(version.response.status, 200);
    assert.equal(version.body.snapshotSchema, 'cogigator.snapshot.v1');
    assert.equal(version.body.analyzeSchema, 'cogigator.analyze.v1');
  });

  it('exposes the current experiment and scenarios', async () => {
    const index = await loadFixtureIndex();
    const current = await requestJson('/experiments/current');
    assert.equal(current.response.status, 200);
    assert.equal(current.body.experimentId, 'industrial-cognition-ab');
    assert.deepEqual(current.body.scenarios, index.scenarios);
    assert.deepEqual(
      current.body.variants.map((variant) => variant.variantId),
      index.variants
    );

    const scenarios = await requestJson('/scenarios');
    assert.equal(scenarios.response.status, 200);
    assert.equal(scenarios.body.scenarios.length, index.scenarios.length);
    assert.deepEqual(
      scenarios.body.scenarios.map((scenario) => scenario.scenarioId),
      index.scenarios
    );
    assert.ok(scenarios.body.scenarios.every((scenario) => scenario.expectedPrimary));
  });

  it('serves every scenario for both variants with the shared snapshot schema', async () => {
    const index = await loadFixtureIndex();
    for (const variantId of index.variants) {
      for (const scenarioId of index.scenarios) {
        const { response, body } = await requestJson(`/snapshot?scenarioId=${scenarioId}&variantId=${variantId}`);
        assert.equal(response.status, 200);
        assert.equal(body.schemaVersion, 'cogigator.snapshot.v1');
        assert.equal(body.experimentId, 'industrial-cognition-ab');
        assert.equal(body.scenarioId, scenarioId);
        assert.equal(body.variant.variantId, variantId);
        assert.ok(Array.isArray(body.cognition.capacities));
        assert.ok(Array.isArray(body.findings));
      }
    }
  });

  it('returns deterministic cited findings from /analyze', async () => {
    const { response, body } = await requestJson('/analyze', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        scenarioId: 'starved-assembler',
        variantId: 'capacity-vector',
        question: 'What is wrong?'
      })
    });

    assert.equal(response.status, 200);
    assert.equal(body.schemaVersion, 'cogigator.analyze.v1');
    assert.equal(body.scenarioId, 'starved-assembler');
    assert.equal(body.variantId, 'capacity-vector');
    assert.equal(body.primaryFindingCode, 'input-starved');
    assert.deepEqual(body.citations.findingCodes, ['input-starved', 'belt-starved']);
    assert.equal(body.citations.stationId, 'field-station-1');
    assert.equal(body.citations.tick, 123456);
    assert.deepEqual(
      body.findings.map((finding) => finding.code),
      ['input-starved', 'belt-starved']
    );
    assert.match(body.cognitionExplanation, /deterministic fixture diagnostics/);
  });

  it('returns proposal-only blueprint drafts without mutating state', async () => {
    const { response, body } = await requestJson('/blueprint-proposal', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        scenarioId: 'starved-assembler',
        variantId: 'capacity-vector',
        intent: 'Fix the starved assembler'
      })
    });

    assert.equal(response.status, 200);
    assert.equal(body.schemaVersion, 'cogigator.blueprint-proposal.v1');
    assert.equal(body.mode, 'proposal-only');
    assert.equal(body.mutation, false);
    assert.equal(body.humanApprovalRequired, true);
    assert.equal(body.primaryFindingCode, 'input-starved');
    assert.ok(body.blueprintString.startsWith('0'));

    const decoded = JSON.parse(inflateSync(Buffer.from(body.blueprintString.slice(1), 'base64')).toString('utf8'));
    assert.equal(decoded.blueprint.item, 'blueprint');
    assert.ok(decoded.blueprint.entities.length > 0);
  });

  it('routes red science intents through the semantic planner', async () => {
    const { response, body } = await requestJson('/blueprint-proposal', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        scenarioId: 'starved-assembler',
        variantId: 'capacity-vector',
        intent: 'Create a tileable red science factory with same-side I/O'
      })
    });

    assert.equal(response.status, 200);
    assert.equal(body.mode, 'proposal-only');
    assert.equal(body.mutation, false);
    assert.equal(body.planner.name, 'red-science-planned-west-io');
    assert.equal(body.planner.status, 'valid');
    assert.equal(body.planner.validation.ok, true);
    assert.ok(body.blueprintString.startsWith('0'));
  });

  it('rejects missing and unknown snapshot parameters', async () => {
    const missing = await requestJson('/snapshot?scenarioId=starved-assembler');
    assert.equal(missing.response.status, 400);
    assert.match(missing.body.error.message, /variantId/);

    const unknown = await requestJson('/snapshot?scenarioId=missing&variantId=cognition-flow');
    assert.equal(unknown.response.status, 400);
    assert.match(unknown.body.error.message, /Unknown scenarioId/);
  });
});
