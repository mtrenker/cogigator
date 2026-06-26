# Infrastructure Context for Cogigator

This document gives implementation agents non-sensitive operational context about the existing Pacabytes Kubernetes + Factorio setup. It intentionally omits secrets, tokens, passwords, private keys, exact node IPs, and sealed-secret contents.

## Purpose

Cogigator is being planned against an existing dedicated Factorio server that already runs in Kubernetes. The implementation plan should account for:

- Factorio runs as a single StatefulSet pod with persistent storage.
- The game server is deployed GitOps-style via ArgoCD from a separate repository.
- RCON exists inside the cluster as a ClusterIP service.
- The game port is exposed at the node/network level using `hostNetwork` and an open UDP firewall rule.
- Any assistant sidecar/bridge should ideally fit this current Kubernetes/GitOps shape instead of assuming a local-only Factorio process.

## Repositories

### Concept repo

- Path: `~/dev/cogigator/`
- Current files:
  - `CONCEPT_BRIEF.md`
  - `PLAN.claude-opus-4-8.md`
  - `PLAN.gpt-5.5.md`
  - `INFRASTRUCTURE.md` (this file)

### Infrastructure repo

- Path: `~/dev/pacabytes/infra/`
- Remote: `git@github.com:mtrenker/infra.git`
- Branch: `main`
- Role: Hetzner Cloud + Kubernetes infrastructure, ArgoCD app-of-apps, ingress, monitoring, sealed secrets.

Important paths:

```text
terraform/                         # Hetzner + Kubernetes infrastructure
argocd/bootstrap/                  # Initial ArgoCD installation/bootstrap manifests
argocd/app-of-apps/root-app.yaml   # App-of-apps root
argocd/applications/               # ArgoCD Application manifests
monitoring/dashboards/             # Grafana dashboards managed by GitOps
monitoring/datasources/            # Grafana/Loki datasource config
docs/                              # Operational docs
scripts/                           # Cluster/admin helper scripts
secrets/                           # Sealed secrets only; do not inspect raw secret values
```

The Factorio ArgoCD application lives at:

```text
~/dev/pacabytes/infra/argocd/applications/factorio.yaml
```

It points to:

```yaml
repoURL: https://github.com/mtrenker/factorio-server
targetRevision: main
path: k8s
namespace: factorio
```

The app has automated sync enabled:

```yaml
automated:
  prune: true
  selfHeal: true
syncOptions:
  - CreateNamespace=true
```

Implication: changes to the Factorio deployment should normally be made in the `factorio-server` repo and pushed to `main`, then ArgoCD reconciles them. Manual cluster mutations may be reverted by ArgoCD.

### Factorio server repo

- Path: `~/dev/pacabytes/factorio-server/`
- Remote: `git@github.com:mtrenker/factorio-server.git`
- Branch: `main`
- Role: Kubernetes manifests for the dedicated Factorio server.

Important paths:

```text
k8s/kustomization.yaml
k8s/base/namespace.yaml
k8s/config/server-settings.yaml
k8s/config/server-adminlist.yaml
k8s/config/mod-list.yaml
k8s/config/sealed-secret.yaml
k8s/config/sealed-secret-mod-credentials.yaml
k8s/workloads/statefulset.yaml
k8s/workloads/service-game.yaml
k8s/workloads/service-rcon.yaml
scripts/create-sealed-secret.sh
scripts/create-mod-credentials-secret.sh
MODS-SETUP.md
README.md
```

## Cluster shape

The production cluster is provisioned on Hetzner Cloud via Terraform.

Non-sensitive summary from repo docs/manifests:

- Provider: Hetzner Cloud
- Region: Nuremberg / EU-central style setup
- Kubernetes: kubeadm-based cluster, version configured around Kubernetes `1.28.x`
- Nodes:
  - 1 control-plane node
  - 2 worker nodes by default
- OS image: Ubuntu 22.04
- Private network: RFC1918 private cluster network
- Pod network: `10.244.0.0/16`
- Service CIDR: `10.96.0.0/12`
- Storage: Hetzner Cloud CSI (`hcloud-volumes` StorageClass)
- Ingress: ingress-nginx exposed through a Terraform-managed Hetzner Load Balancer
- TLS: cert-manager with Let's Encrypt issuer
- GitOps: ArgoCD app-of-apps
- Secrets in Git: Sealed Secrets
- Monitoring/logging: kube-prometheus-stack, Grafana, Loki, Promtail, metrics-server

Known ArgoCD applications in the infra repo include:

```text
cert-manager
cloudnative-pg
crowdsec
factorio
grafana-dashboards
hcloud-csi
ingress-nginx
kube-prometheus-stack
loki
metrics-server
promtail
sealed-secrets
```

There are additional app workloads unrelated to Cogigator/Factorio.

## Access model and kubectl note

`kubectl` is available on the workstation, but live cluster access may require the correct Tailscale path/context. During this documentation pass, `kubectl` calls to the configured API server timed out. Treat live state as "verify when connected" rather than guaranteed from this file.

Useful live checks once Tailscale/kubeconfig is available:

```bash
kubectl get ns
kubectl get pods -n factorio -o wide
kubectl get svc -n factorio -o wide
kubectl get pvc -n factorio
kubectl get events -n factorio --sort-by='.lastTimestamp'
kubectl top pod -n factorio
kubectl get application -n argocd factorio
```

Do not include command output containing secrets in future planning docs.

## Factorio workload

The server is defined as a Kubernetes StatefulSet:

```text
~/dev/pacabytes/factorio-server/k8s/workloads/statefulset.yaml
```

Current shape:

- Kind: `StatefulSet`
- Name: `factorio`
- Namespace: `factorio`
- Replicas: `1`
- Container image: `factoriotools/factorio:2.0.77-rootless`
- Runs non-root as UID/GID-style user `1000`
- Uses `hostNetwork: true`
- DNS policy: `ClusterFirstWithHostNet`
- Persistent volume claim:
  - Name template: `factorio-data`
  - StorageClass: `hcloud-volumes`
  - Size: `20Gi`
  - Access mode: `ReadWriteOnce`
- Main data mount: `/factorio`
- Save behavior:
  - `LOAD_LATEST_SAVE=true`
  - `GENERATE_NEW_SAVE=true`
  - `SAVE_NAME=my-server`
  - `UPDATE_MODS_ON_START=true`

Resource requests/limits:

```yaml
requests:
  cpu: "2000m"
  memory: "2Gi"
limits:
  cpu: "3000m"
  memory: "4Gi"
```

Health checks:

- Readiness probe: TCP on RCON port
- Liveness probe: TCP on RCON port

## Factorio networking

### Game traffic

Manifest:

```text
~/dev/pacabytes/factorio-server/k8s/workloads/service-game.yaml
```

- Service name: `factorio-game`
- Namespace: `factorio`
- Service type: headless ClusterIP (`clusterIP: None`)
- Port: UDP `34197`
- Pod uses `hostNetwork: true`, so the game binds directly to the Kubernetes node network namespace.
- The infra firewall allows public UDP traffic on the Factorio game port.

Implication for Cogigator: do not assume a normal LoadBalancer/Ingress path for the Factorio game protocol. If a companion bridge needs to run close to the game, the cleanest options are likely:

1. A sidecar or second container in the same pod.
2. A separate Deployment in the same namespace using the `factorio-rcon` ClusterIP service.
3. A debug/local process using `kubectl port-forward` to RCON.

### RCON management traffic

Manifest:

```text
~/dev/pacabytes/factorio-server/k8s/workloads/service-rcon.yaml
```

- Service name: `factorio-rcon`
- Namespace: `factorio`
- Service type: `ClusterIP`
- Port: TCP `27015`
- Target port: TCP `27015`

RCON is intentionally internal to the cluster. Local/admin access is normally through port-forwarding:

```bash
kubectl port-forward -n factorio svc/factorio-rcon 27015:27015
```

The RCON password exists inside Factorio config/secret material and must not be copied into planning docs.

Implication for Cogigator: a Kubernetes-native assistant bridge can access RCON through:

```text
factorio-rcon.factorio.svc.cluster.local:27015
```

or simply:

```text
factorio-rcon:27015
```

when running in the `factorio` namespace.

## Factorio configuration

### Server settings

Manifest:

```text
~/dev/pacabytes/factorio-server/k8s/config/server-settings.yaml
```

Non-sensitive settings:

- Server name: `Pacabytes Factorio Server`
- Max players: `5`
- Public visibility: disabled
- LAN visibility: disabled
- User verification: enabled
- Commands: `admins-only`
- Autosave interval: 10 minutes
- Autosave slots: 5
- Auto-pause when no players are present: enabled
- Only admins can pause: enabled

Secrets are injected by init container from Kubernetes Secrets where present. Do not hard-code or document secret values.

### Admin list

Manifest:

```text
~/dev/pacabytes/factorio-server/k8s/config/server-adminlist.yaml
```

The server has a configured admin list. Avoid relying on a specific player name in generated plans unless needed.

### Mods

Manifest:

```text
~/dev/pacabytes/factorio-server/k8s/config/mod-list.yaml
```

Current enabled mods include:

```text
base
space-age
bullet-trails
stdlib2
flib
RateCalculator
informatron
Todo-List
factoryplanner
LogisticTrainNetwork
squeak-through-2
aai-containers
WideChests
WideChests-aai-reskin
calculator-ui
GUI_Unifyer
textplates
Nanobots2
```

Implications for Cogigator:

- The target Factorio version is 2.0/Space Age.
- Mod compatibility matters.
- Existing helper libraries such as `flib` may be available if Cogigator is added to the same mod pack.
- Existing planning/calculator mods mean Cogigator should complement rather than duplicate everything; focus on situated observation, explanation, and player-approved actions.

## Secrets and credentials

Existing secret-related files are sealed/encrypted or generated by scripts:

```text
k8s/config/sealed-secret.yaml
k8s/config/sealed-secret-mod-credentials.yaml
scripts/create-sealed-secret.sh
scripts/create-mod-credentials-secret.sh
```

Do not read, decode, print, or include secret values in implementation plans.

For Cogigator, any new secret should be handled through the same pattern:

- store plaintext only locally/temporarily during creation;
- create a Kubernetes Secret or use `kubeseal`;
- commit only sealed secret manifests;
- never commit API keys, RCON passwords, Factorio tokens, or model provider credentials.

Potential future Cogigator secrets:

- LLM provider API key, if using a hosted provider.
- RCON password reference, if the assistant bridge needs direct RCON.
- Optional webhook/shared secret for any local dashboard or callback endpoint.

## Monitoring/logging

The infra repo includes:

- kube-prometheus-stack
- Grafana
- AlertManager
- Node Exporter
- kube-state-metrics
- Loki
- Promtail
- metrics-server

Useful planning implications:

- A Cogigator bridge pod can expose Prometheus metrics if useful.
- Logs should go to stdout/stderr so Promtail/Loki can collect them.
- Basic dashboards can be added via GitOps in `~/dev/pacabytes/infra/monitoring/dashboards/`.
- Resource usage must be conservative: the cluster already hosts multiple workloads, and Factorio has explicit CPU/memory budgets.

Suggested bridge metrics:

```text
cogigator_rcon_requests_total
cogigator_rcon_errors_total
cogigator_snapshot_duration_seconds
cogigator_llm_requests_total
cogigator_llm_request_duration_seconds
cogigator_llm_tokens_total
cogigator_actions_proposed_total
cogigator_actions_approved_total
cogigator_actions_rejected_total
```

## Deployment implications for Cogigator

A more precise implementation plan should consider these deployment patterns.

### Option A: Mod + in-cluster bridge Deployment

- Factorio mod runs in the existing Factorio server.
- A separate `cogigator-bridge` Deployment runs in the `factorio` namespace.
- Bridge talks to Factorio via `factorio-rcon:27015` and/or future UDP/file mechanisms.
- Bridge stores no state or only ephemeral/cache state initially.
- Secrets are mounted from Kubernetes Secrets/SealedSecrets.
- Logs/metrics integrate with existing monitoring.

Pros:

- Minimal change to the existing StatefulSet.
- Good separation between Factorio runtime and AI process.
- Easy to restart/update bridge independently.
- Fits GitOps well.

Cons:

- RCON is request/response and limited for rich game-state streaming.
- Any file-based integration with `/factorio` data requires PVC sharing or sidecar design.

### Option B: Mod + sidecar container in the Factorio StatefulSet

- Add a second container to the existing `factorio` StatefulSet.
- Sidecar shares pod network with Factorio and can use localhost RCON.
- Sidecar could potentially share mounted volumes if file-based exchange is needed.

Pros:

- Lowest-latency local access to Factorio/RCON.
- Easier file sharing if the mod writes script-output data.
- Strong lifecycle coupling with the game server.

Cons:

- Changes the critical game StatefulSet.
- Sidecar failure/resource usage may impact the server pod.
- Harder to iterate without restarting or disturbing the game pod.

### Option C: Local development bridge via port-forward

- Developer runs Cogigator bridge locally.
- Connects to RCON using `kubectl port-forward`.
- Useful for early MVP/prototyping.

Pros:

- Fast development.
- No in-cluster LLM/API secrets needed at first.
- Easy debugging.

Cons:

- Not production-like.
- Requires developer machine and active port-forward.
- Not suitable as the final always-on companion.

## Recommended direction for updated plans

Use a staged approach:

1. Local prototype:
   - Build Factorio mod and local bridge.
   - Use RCON via `kubectl port-forward` for simple commands/queries.
   - Avoid permanent cluster changes until the contract is proven.
2. In-cluster bridge Deployment:
   - Add a `cogigator-bridge` workload to the `factorio-server` repo or a dedicated repo with an ArgoCD Application.
   - Run it in the `factorio` namespace.
   - Use `factorio-rcon` service for RCON.
   - Use sealed secrets for provider/RCON credentials.
   - Expose metrics/logs for monitoring.
3. Optional sidecar or richer transport:
   - Only move to sidecar/shared-volume or UDP/file streaming once the mod-to-bridge protocol is stable and there is a clear need for richer telemetry than RCON allows.

## Key constraints for models to respect

- Do not put secrets in plans, code examples, manifests, or docs.
- Do not assume public HTTP ingress is appropriate for the assistant control surface.
- Do not expose RCON publicly.
- Prefer GitOps changes over manual `kubectl apply` for persistent changes.
- Treat the existing Factorio StatefulSet as critical: minimize restarts and resource contention.
- Keep Factorio UPS/server performance as a first-class requirement.
- Any world-mutating AI action should remain player-approved and auditable.
- Any live cluster state should be re-verified with `kubectl` once Tailscale/kubeconfig access is working.
