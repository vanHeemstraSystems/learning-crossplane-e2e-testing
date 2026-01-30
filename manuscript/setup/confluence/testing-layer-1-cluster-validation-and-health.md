# Layer 1 — Cluster Validation & Health

## Purpose

Layer 1 validates that the **platform runtime is healthy** and that Crossplane can reliably accept and reconcile configuration changes in a real Kubernetes cluster.

This layer is intended to answer:

- “Is Crossplane installed and stable?”
- “Are providers and functions installed and Healthy?”
- “Do webhooks behave reliably (no repeated timeouts/handshake failures)?”
- “Can we apply XRDs/Compositions and observe consistent reconciliation?”

## Why it matters

Even perfect composition logic (Layer 0) can fail in practice due to cluster-level concerns:

- webhook instability or API server timeouts
- provider pods not running or not Healthy
- ProviderConfig errors (credentials, RBAC, namespace mistakes)
- function packages not installed / failing health checks

Layer 1 reduces noise before you run slower end-to-end and cloud verification layers.

## Tools and methods

- **kubectl-based health checks**
  - core components: `kubectl get pods -n crossplane-system`
  - providers/functions: `kubectl get providers`, `kubectl get functions`
  - readiness/health: `kubectl wait ... --for=condition=healthy`
- **Webhook stabilization (Crossplane v2)**
  - patch webhook timeouts when the API server is under load (common on local clusters)
- **Pre-test health script**
  - in `dev.md`: `scripts/check-crossplane-health.sh`
- **Optional: provider validation with Uptest**
  - validate individual managed resources (create → ready → delete) with cloud-friendly defaults

## Typical workflow

1. Install Crossplane and verify core pods are stable.
2. Patch webhook timeouts if you see intermittent webhook handshake/timeouts.
3. Install providers/functions and wait for Healthy conditions.
4. Apply XRDs/Compositions and verify they exist (`kubectl get xrd`, `kubectl get composition`).
5. Run the health script prior to executing test suites.
6. (Optional) Run Uptest provider validation to prove the provider can create and clean up Azure resources.

## What “good” looks like (guidance)

- Crossplane core deployment is Available and pods are stable.
- Providers and functions reach **Healthy** without repeated restarts.
- Applying manifests does not produce consistent OpenAPI fetch timeouts or webhook handshake errors.
- When you create an XR, it progresses to **Synced/Ready** (assuming credentials and cloud quotas are valid).

## Common failure modes (and what to check)

- **Webhook-related errors**
  - symptoms: TLS handshake timeout, context deadline exceeded during `kubectl apply`
  - actions: verify API server health; apply webhook timeout patch; re-try apply with `--validate=false` if appropriate

- **Provider not Healthy**
  - symptoms: provider revision unhealthy; provider pods crashlooping
  - actions: inspect provider logs, check credentials secret format, confirm ProviderConfig exists

- **Function not Healthy**
  - symptoms: pipeline steps not executing; function health checks failing
  - actions: check function resource status and logs; confirm function packages installed

- **Provider looks Healthy, but cloud operations fail**
  - symptoms: managed resources stuck, repeated auth or Azure API errors
  - actions: validate `ProviderConfig` and credentials; run a small Uptest case (e.g., ResourceGroup) to isolate provider/credential issues

## Relationship to other layers

- Layer 1 is a prerequisite for Layers 2–5.
- If Layer 1 is unstable, higher layers tend to produce misleading failures and long debugging cycles.

## Notes on Uptest placement (alignment with `dev.md`)

In our strategy, **Uptest is an optional Layer 1 technique**: it validates provider capability and credentials early, before running longer KUTTL E2E suites.

