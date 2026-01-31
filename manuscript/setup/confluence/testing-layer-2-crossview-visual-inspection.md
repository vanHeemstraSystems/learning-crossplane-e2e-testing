# Layer 2 — Crossview (Visual Inspection & Composition Debugging)

## Purpose

Layer 2 provides a **visual, relationship-oriented debugging layer** for Crossplane. It helps engineers understand and troubleshoot how XRs map to Compositions and managed resources in practice.

This layer is intended to answer:

- “Is my XR selecting the correct Composition?”
- “Which managed resources were created and how are they related to the XR?”
- “Which conditions/events explain why an XR is not Ready?”

## Why it matters

Crossplane systems are distributed by nature: a single XR drives multiple managed resources, often across namespaces and with asynchronous readiness.

While the CLI is authoritative, a UI that visualizes relationships reduces time-to-diagnosis:

- quickly identifying missing resources or failed patches
- understanding the XR→Composition→managed resource graph
- spotting reconciliation loops and dependency issues

## Tools and methods

- **Crossview**
  - installation via Helm (as described in `testing-demo.md`)
  - built-in PostgreSQL backing store (Crossview deploys its own Postgres)
- **CLI validation helpers**
  - optional scripts that validate XRD ↔ Composition matching
- **Optional: Komoplane**
  - lightweight troubleshooting UI for Kubernetes resources (not Crossplane-specific)

## What you typically inspect

Using the PostgreSQL example from `testing-demo.md`:

- XRD: `xpostgresqldatabases.database.example.io`
- Composition: `xpostgresqldatabases.database.example.io`
- Example XR: `xpostgresqldatabase default/test-postgres-e2e-001`

In Crossview, you generally validate:

- **XRD schema**: does it expose the expected parameters?
- **Composition selection**: does label/selector logic match the XR?
- **Managed resources**: are the expected Azure resources created (server + database + resource group)?
- **Status/conditions**: where in the lifecycle reconciliation is failing

## What “good” looks like (guidance)

- The XR shows **Synced=True** and eventually **Ready=True**.
- Managed resources appear as expected and show stable condition progression.
- Errors are explainable and actionable (e.g., naming, quota, permissions).

## Limitations

Crossview does not replace automated checks:

- it is not a test runner (Layer 3)
- it cannot validate cloud-side correctness beyond what the provider reports (Layer 4)
- it is not a GitOps control plane (Layer 5)

Instead, it is best used as an **interactive diagnostic accelerator** during development and incident analysis.

## Crossview vs kubectl (practical guidance)

Use `kubectl` when you need authoritative YAML, logs, or automation; use Crossview when you need to understand the **resource graph** quickly.

- **kubectl excels at**: scripting, CI checks, exporting YAML, precise condition inspection
- **Crossview excels at**: XR→managed resource visualization and fast diagnosis of “what is failing where”

## Optional alternative: Komoplane

If you prefer a simpler UI for general Kubernetes troubleshooting, Komoplane can be used alongside Crossview. In our strategy, Crossview remains the primary Crossplane-specific visualization tool.

