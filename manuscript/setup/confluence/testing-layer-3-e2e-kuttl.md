# Layer 3 — In-Cluster End-to-End Tests (KUTTL)

## Purpose

Layer 3 validates **end-to-end reconciliation behavior** inside Kubernetes by executing test suites that create, assert, and delete Crossplane resources.

This layer is intended to answer:

- “Does the XR reconcile successfully in a real cluster?”
- “Do composed managed resources reach Ready within expected timeouts?”
- “Does cleanup work (deletion, finalizers, and resource teardown)?”

## Why it matters

E2E tests validate the full system boundary within Kubernetes:

- Crossplane core controllers
- provider controllers
- composition functions
- actual reconciliation loops and readiness conditions

This is where “it renders” becomes “it works”.

## Tools and methods

- **KUTTL** (`kubectl-kuttl`)
  - executes ordered steps (e.g., `00-*.yaml`, `01-*.yaml`) within a test case directory
  - supports assertions via `kubectl wait` and script-based checks

In `dev.md` we use:

- suite config: `tests/e2e/kuttl-test.yaml`
- PostgreSQL suite: `tests/e2e/postgresql-databases/basic/`
  - example XR: `XPostgreSQLDatabase default/test-postgres-e2e-001`

## Test design principles (guidance)

- **Use explicit timeouts** suited for cloud provisioning (often 20–40 minutes in total).
- **Assert conditions, not just existence**
  - e.g., wait for XR `Synced=True` and `Ready=True`
  - wait for managed resources to become `Ready=True`
- **Isolate test resources**
  - use predictable labels and names
  - keep one XR per test case when possible
- **Always validate cleanup**
  - deletion is part of platform correctness (finalizers, dependencies, and ordering)
  - ensure the suite includes explicit delete steps and assertions

## What “good” looks like (guidance)

- All KUTTL suites pass reliably with stable timing.
- The XR and managed resources reach Ready without manual intervention.
- Cleanup completes and does not leave orphaned managed resources.

## Common failure modes

- **Timeouts due to cloud latency**
  - adjust suite timeouts and use `kubectl wait` with realistic windows

- **ProviderConfig / credentials issues**
  - symptoms: managed resources stuck not ready with auth errors
  - action: validate secrets and ProviderConfig as part of Layer 1 health

- **Name/constraint failures (Azure)**
  - symptoms: `READY=False` with name constraints or already-taken names
  - action: change XR name and re-run

## Relationship to other layers

- Layer 3 depends on Layer 1 stability.
- Layer 4 complements Layer 3 by verifying cloud-side reality beyond Kubernetes conditions.

## Practical notes (alignment with `dev.md`)

- Prefer running suites via the shared config file so timeout behavior is consistent: `tests/e2e/kuttl-test.yaml`.
- Where needed, use the cleanup script approach (delete XRs, then confirm cloud resources are not orphaned).

