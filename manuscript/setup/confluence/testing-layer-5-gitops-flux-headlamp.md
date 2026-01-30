# Layer 5 — GitOps Continuous Delivery & Monitoring (Flux + Headlamp)

## Purpose

Layer 5 validates that our platform configuration (Crossplane, providers, compositions, and XR instances) can be delivered and operated through **GitOps**.

This layer is intended to answer:

- “Are platform changes applied continuously from Git, with clear reconciliation status?”
- “Can we detect and correct drift automatically?”
- “Do we have operational visibility into delivery pipelines and failures?”

## Why it matters

In a platform context, success is not only “it works once” but also:

- “it keeps working as desired state changes”
- “it is reproducible across environments”
- “it is observable and supportable by on-call engineers”

GitOps provides the operational control plane that makes Crossplane platform delivery scalable.

## Tools and methods

- **Flux**
  - bootstraps the cluster and continuously reconciles manifests from a Git repository
  - provides status primitives (Sources, Kustomizations, HelmReleases) that are easy to automate and monitor
- **Headlamp (with Flux plugin)**
  - provides a UI view of Flux reconciliation status, errors, and events
  - helps engineers quickly identify which Kustomization or HelmRelease is failing and why
- **Optional: Flux Notifications**
  - alert on reconciliation failures (e.g., Slack)
- **Optional: CI validation**
  - validate Flux manifests in pull requests (prevent obvious schema/YAML issues from merging)

In `dev.md` we install Flux, define a GitOps directory structure, and show Headlamp installation via Flux controllers.

Key object names used in `dev.md` (so dashboards and runbooks align):

- `GitRepository`: `crossplane-configs` (namespace `flux-system`)
- `Kustomization`: `crossplane-apis` (namespace `flux-system`)

## Operational workflow (conceptual)

1. Engineers commit platform configuration changes (XRDs, Compositions, provider updates, functions).
2. Flux detects changes and reconciles them into the cluster.
3. Operators monitor:
   - Flux resource readiness (Ready/Failed/Suspended)
   - reconciliation events and controller logs
4. If something fails:
   - rollback is a Git revert
   - drift is corrected automatically (or surfaced for decision)

## What “good” looks like (guidance)

- Flux shows all relevant Kustomizations and HelmReleases as **Ready**.
- Drift is reconciled predictably and safely.
- Headlamp provides quick visibility into:
  - which component failed (source, kustomization, helm release)
  - what changed (commit references)
  - the actionable error messages/events

## Failure modes (common)

- **Source authentication / Git access**
  - symptoms: Source not Ready, authentication errors
  - actions: validate token/secret configuration, confirm repo URL and permissions

- **Invalid manifests**
  - symptoms: Kustomization fails apply/health checks
  - actions: use Layer 0 and Layer 1 validations before commit; inspect events in Flux/Headlamp

- **Helm release stuck**
  - symptoms: HelmRelease not Ready
  - actions: inspect helm-controller logs, reconcile/suspend/resume as needed

- **No alerts / missed failures**
  - symptoms: failures only discovered after impact
  - actions: enable Flux Notifications (error severity at minimum) for key sources/kustomizations

## Relationship to other layers

- Layer 5 does not replace functional validation (Layers 0–4).
- It ensures platform changes are **deliverable, observable, and reversible**—which is essential for multi-environment operations.

## Optional extensions (recommended for teams)

### Notifications (Slack example)

Configure Flux to emit alerts for failures on the core GitRepository/Kustomization. This is described in `dev.md` as an optional section under Flux installation.

### CI validation (GitHub Actions example)

Validate Flux manifests in pull requests to catch obvious failures before merge. This is described in `dev.md` as an optional section under Flux installation.

