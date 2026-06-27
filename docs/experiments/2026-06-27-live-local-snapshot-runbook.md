# Runbook: Live Local Read-Only Snapshot Export

- Date: 2026-06-27
- Status: tested locally
- Scope: local Windows Factorio save + WSL bridge only
- Related synthesis: [Cognition Network Synthesis](2026-06-27-industrial-cognition-synthesis.md)

## What this tests

This runbook tests a local-only read path from the running Factorio mod to the bridge:

```text
Factorio local save
  -> /cogigator-export-snapshot
  -> script-output/cogigator/live-snapshot.json
  -> WSL bridge with COGIGATOR_LIVE_SNAPSHOT_FILE
  -> Pi cogigator_snapshot(... scenarioId="live-local" ...)
```

It does **not** connect to the live server, Kubernetes, RCON, or any remote runtime.
It does **not** add assistant-controlled mutation.

## 1. Update the Windows mod copy

From WSL repo root:

```bash
MODS_DIR="/mnt/c/Users/MartinTrenker/AppData/Roaming/Factorio/mods"
rm -rf "$MODS_DIR/cogigator_0.1.0"
cp -r factorio-mod/cogigator "$MODS_DIR/cogigator_0.1.0"
```

Restart Factorio after copying.

## 2. Export a snapshot from Factorio

In a local test save:

1. Place a **Cogigator Field Station**.
2. Confirm it has a worksite:

   ```text
   /cogigator-status
   /cogigator-worksites
   ```

3. Export one read-only snapshot:

   ```text
   /cogigator-export-snapshot
   ```

Expected Factorio output:

```text
[cogigator] exported live read-only snapshot for <station-id> to script-output/cogigator/live-snapshot.json
```

Expected Windows file:

```text
C:\Users\MartinTrenker\AppData\Roaming\Factorio\script-output\cogigator\live-snapshot.json
```

Expected WSL path:

```bash
/mnt/c/Users/MartinTrenker/AppData/Roaming/Factorio/script-output/cogigator/live-snapshot.json
```

## 3. Start bridge with live snapshot file

From WSL repo root:

```bash
COGIGATOR_LIVE_SNAPSHOT_FILE="/mnt/c/Users/MartinTrenker/AppData/Roaming/Factorio/script-output/cogigator/live-snapshot.json" \
PORT=8787 node bridge/server.mjs
```

## 4. Query the live-local snapshot

In another WSL terminal:

```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=live-local&variantId=cognition-flow" | jq '{scenarioId,variantId:.variant.variantId,station,worksite,tick,findings,truncated,omitted}'
```

If the save is currently using `capacity-vector`, request that variant instead:

```bash
curl -sS "http://127.0.0.1:8787/snapshot?scenarioId=live-local&variantId=capacity-vector" | jq
```

The bridge rejects mismatched variants so fixture and live outputs cannot be accidentally compared under the wrong variant label.

## 5. Pi check

With the bridge running, call the tool/command using:

```text
/cogigator-snapshot live-local cognition-flow
```

or:

```text
/cogigator-snapshot live-local capacity-vector
```

depending on the exported file's variant.

## Local test result

Verified on 2026-06-27 with Windows Factorio + WSL bridge:

- `/cogigator-export-snapshot` wrote `script-output/cogigator/live-snapshot.json`.
- WSL bridge loaded the file through `COGIGATOR_LIVE_SNAPSHOT_FILE`.
- `GET /snapshot?scenarioId=live-local&variantId=cognition-flow` returned the exported live-local snapshot.
- Observed exported shape: `scenarioId=live-local`, `variantId=cognition-flow`, `worksite=32x32`, findings present.

## Safety notes

- The Factorio mod only reads entities in the assigned worksite.
- The mod writes a JSON file to local `script-output`; it does not expose a socket or remote API.
- The bridge only reads the file when explicitly configured with `COGIGATOR_LIVE_SNAPSHOT_FILE`.
- No live server, Kubernetes, RCON, or remote deployment is involved.
- The assistant still has no action/mutation endpoint.
