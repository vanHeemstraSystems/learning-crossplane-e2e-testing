# Layer 0 — Local Composition Rendering

## Purpose

Layer 0 provides the **fastest feedback loop** for Crossplane development by validating composition behavior **without requiring a Kubernetes cluster** and without touching cloud APIs.

This layer is intended to answer:

- “Does my **XRD + Composition + example XR** render successfully?”
- “Do patches/transforms select the right fields?”
- “Which managed resources would be created by this composition pipeline?”

## Why it matters

Local rendering catches a large class of issues early:

- invalid field paths in patches/transforms
- function pipeline wiring problems
- schema mismatches between XR parameters and composition expectations
- unintended managed resource shapes before any reconciliation begins

## Tools and methods

- **Crossplane CLI**: `crossplane render`
- **Examples-as-contract**: minimal example XR manifests used as render inputs
- **Render-all script (recommended)**: validate every API package under `apis/v1alpha1/*/`
- **CI validation (recommended)**: run rendering on each pull request to catch composition drift early

In `testing-demo.md` we use the PostgreSQL API package:

- XRD: `apis/v1alpha1/postgresql-databases/xrd.yaml`
- Composition: `apis/v1alpha1/postgresql-databases/composition.yaml`
- Render example: `apis/v1alpha1/postgresql-databases/examples/basic.yaml`

## How it’s typically used

### Developer workflow

1. Modify `xrd.yaml` / `composition.yaml` (and/or function inputs).
2. Run `crossplane render` against one or more example XRs.
3. Inspect the rendered output for expected managed resources and patched values.
4. Only then apply to a cluster (Layer 1+).

### Team workflow (pre-commit / CI)

For teams, local rendering becomes most valuable when it is **standardized**:

- **Local pre-commit habit**: render the API(s) you changed before pushing
- **Repository-wide guardrail**: run a “render all APIs” job in CI to prevent broken compositions from merging

In `testing-demo.md` we implement this pattern via:

- `scripts/render-all.sh` (renders all API packages that have examples)
- a lightweight GitHub Actions workflow that runs the script on push/PR

### Expected outputs

- A rendered YAML document (`rendered-output.yaml`) containing:
  - the XR
  - the composed managed resources that would be created
  - optional function results (useful for debugging)

## Quality bar (guidance)

Layer 0 is considered “passing” when:

- `crossplane render` succeeds for the relevant example(s)
- the rendered output contains the expected managed resource kinds (e.g., PostgreSQL server + database)
- key parameters (region, resource group, database name) appear in the right places

## Limitations

Layer 0 does **not** validate:

- provider installation and permissions
- webhook stability in a real cluster
- runtime reconciliation behavior, readiness conditions, or retries
- actual cloud-side creation (Azure APIs)

Those concerns are covered in Layers 1–5.

