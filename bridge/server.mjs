import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

const BRIDGE_SCHEMA_VERSION = 'cogigator.bridge.v1';
const ANALYZE_SCHEMA_VERSION = 'cogigator.analyze.v1';
const BRIDGE_VERSION = '0.1.0-local';
const __dirname = dirname(fileURLToPath(import.meta.url));
const fixturesDir = join(__dirname, 'fixtures');

const scenarioTitles = {
  'starved-assembler': 'Starved assembler',
  'blocked-output': 'Blocked output',
  'missing-fluid': 'Missing fluid',
  'low-power': 'Low power',
  'under-computed': 'Under-computed station',
  'dense-cell-truncated': 'Dense cell with truncation'
};

let fixtureIndexPromise;
const snapshotCache = new Map();

function nowIso() {
  return new Date().toISOString();
}

function responseEnvelope(extra = {}) {
  return {
    schemaVersion: BRIDGE_SCHEMA_VERSION,
    requestId: randomUUID(),
    serverTime: nowIso(),
    ...extra
  };
}

function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body, null, 2);
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store'
  });
  res.end(`${payload}\n`);
}

function sendError(res, statusCode, message, details = {}) {
  sendJson(res, statusCode, responseEnvelope({
    status: 'error',
    error: { message, ...details }
  }));
}

async function readJson(path) {
  return JSON.parse(await readFile(path, 'utf8'));
}

export async function loadFixtureIndex() {
  if (!fixtureIndexPromise) {
    fixtureIndexPromise = readJson(join(fixturesDir, 'index.json'));
  }
  return fixtureIndexPromise;
}

export async function loadSnapshot(scenarioId, variantId) {
  const index = await loadFixtureIndex();
  if (!index.scenarios.includes(scenarioId)) {
    const allowed = index.scenarios.join(', ');
    throw Object.assign(new Error(`Unknown scenarioId: ${scenarioId}`), {
      statusCode: 400,
      details: { allowedScenarios: index.scenarios, hint: `Use one of: ${allowed}` }
    });
  }
  if (!index.variants.includes(variantId)) {
    const allowed = index.variants.join(', ');
    throw Object.assign(new Error(`Unknown variantId: ${variantId}`), {
      statusCode: 400,
      details: { allowedVariants: index.variants, hint: `Use one of: ${allowed}` }
    });
  }

  const cacheKey = `${variantId}/${scenarioId}`;
  if (!snapshotCache.has(cacheKey)) {
    snapshotCache.set(
      cacheKey,
      readJson(join(fixturesDir, variantId, `${scenarioId}.json`))
    );
  }
  return snapshotCache.get(cacheKey);
}

async function loadVariants(index) {
  const snapshots = await Promise.all(
    index.variants.map((variantId) => loadSnapshot(index.scenarios[0], variantId))
  );
  return snapshots.map((snapshot) => snapshot.variant);
}

async function listScenarios(index) {
  const baselineVariant = index.variants[0];
  return Promise.all(index.scenarios.map(async (scenarioId) => {
    const snapshot = await loadSnapshot(scenarioId, baselineVariant);
    const primary = snapshot.expectedDiagnosis?.find((entry) => entry.primary);
    return {
      scenarioId,
      title: scenarioTitles[scenarioId] ?? scenarioId,
      expectedPrimary: primary?.findingCode ?? snapshot.findings[0]?.code ?? null
    };
  }));
}

function explainCognition(snapshot) {
  const degradation = snapshot.cognition?.degradation;
  if (!degradation?.degraded) {
    return 'All cognition capacities are satisfied; findings come from deterministic fixture diagnostics.';
  }

  const bottlenecks = snapshot.cognition.capacities
    .filter((capacity) => capacity.bottleneck || !capacity.satisfied)
    .map((capacity) => `${capacity.label}: ${capacity.note}`)
    .filter(Boolean);

  const effects = degradation.effects?.length
    ? ` Effects: ${degradation.effects.join(', ')}.`
    : '';
  const reasons = degradation.reasons?.length
    ? ` Reasons: ${degradation.reasons.join(', ')}.`
    : '';

  return [
    `Cognition is ${degradation.level} for ${snapshot.variant.variantId}.`,
    bottlenecks.join(' '),
    reasons,
    effects
  ].filter(Boolean).join(' ').replace(/\s+/g, ' ').trim();
}

function analyzeSnapshot(snapshot, question = '') {
  const primaryDiagnosis = snapshot.expectedDiagnosis?.find((entry) => entry.primary);
  const primaryFindingCode = primaryDiagnosis?.findingCode ?? snapshot.findings[0]?.code ?? null;

  return {
    schemaVersion: ANALYZE_SCHEMA_VERSION,
    requestId: randomUUID(),
    serverTime: nowIso(),
    experimentId: snapshot.experimentId,
    scenarioId: snapshot.scenarioId,
    variantId: snapshot.variant.variantId,
    question,
    citations: {
      stationId: snapshot.station.stationId,
      tick: snapshot.tick,
      findingCodes: snapshot.findings.map((finding) => finding.code)
    },
    findings: snapshot.findings,
    primaryFindingCode,
    expectedDiagnosis: snapshot.expectedDiagnosis ?? [],
    cognitionExplanation: explainCognition(snapshot),
    truncated: snapshot.truncated
  };
}

async function readRequestJson(req) {
  let body = '';
  for await (const chunk of req) {
    body += chunk;
  }
  if (!body.trim()) {
    return {};
  }
  try {
    return JSON.parse(body);
  } catch {
    throw Object.assign(new Error('Request body must be valid JSON'), { statusCode: 400 });
  }
}

function requireQueryParam(url, name) {
  const value = url.searchParams.get(name);
  if (!value) {
    throw Object.assign(new Error(`Missing required query parameter: ${name}`), {
      statusCode: 400
    });
  }
  return value;
}

async function route(req, res) {
  const url = new URL(req.url, 'http://localhost');
  const index = await loadFixtureIndex();

  if (req.method === 'GET' && url.pathname === '/health') {
    return sendJson(res, 200, responseEnvelope({ status: 'ok' }));
  }

  if (req.method === 'GET' && url.pathname === '/version') {
    return sendJson(res, 200, responseEnvelope({
      bridgeVersion: BRIDGE_VERSION,
      snapshotSchema: index.schemaVersion,
      analyzeSchema: ANALYZE_SCHEMA_VERSION
    }));
  }

  if (req.method === 'GET' && url.pathname === '/experiments/current') {
    return sendJson(res, 200, responseEnvelope({
      experimentId: index.experimentId,
      snapshotSchema: index.schemaVersion,
      variants: await loadVariants(index),
      scenarios: index.scenarios
    }));
  }

  if (req.method === 'GET' && url.pathname === '/scenarios') {
    return sendJson(res, 200, responseEnvelope({
      scenarios: await listScenarios(index)
    }));
  }

  if (req.method === 'GET' && url.pathname === '/snapshot') {
    const scenarioId = requireQueryParam(url, 'scenarioId');
    const variantId = requireQueryParam(url, 'variantId');
    return sendJson(res, 200, await loadSnapshot(scenarioId, variantId));
  }

  if (req.method === 'POST' && url.pathname === '/analyze') {
    const body = await readRequestJson(req);
    if (!body.scenarioId || !body.variantId) {
      return sendError(res, 400, 'Request body requires scenarioId and variantId');
    }
    const snapshot = await loadSnapshot(body.scenarioId, body.variantId);
    return sendJson(res, 200, analyzeSnapshot(snapshot, body.question ?? ''));
  }

  return sendError(res, 404, `No route for ${req.method} ${url.pathname}`);
}

export function createBridgeServer() {
  return createServer(async (req, res) => {
    try {
      await route(req, res);
    } catch (error) {
      const statusCode = error.statusCode ?? 500;
      sendError(res, statusCode, error.message, error.details);
    }
  });
}

export async function startBridgeServer({ port = process.env.PORT ?? 8787, host = process.env.HOST ?? '127.0.0.1' } = {}) {
  const server = createBridgeServer();
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(Number(port), host, () => {
      server.off('error', reject);
      resolve();
    });
  });
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const server = await startBridgeServer();
  const address = server.address();
  console.log(`Cogigator bridge listening on http://${address.address}:${address.port}`);
}
