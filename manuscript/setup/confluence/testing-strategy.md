# Testing Strategy (Crossplane Platform)

This page defines our **testing strategy** for Crossplane compositions and the platform delivery lifecycle described in `manuscript/setup/dev.md`.

We use a **6-layer approach** to balance **speed, cost, and fidelity**. The intent is to validate quickly and locally first, then progressively increase realism (cluster reconciliation, end-to-end tests, cloud verification, and GitOps operations).

---

## Goals

- **Confidence**: detect breaking changes to XRDs, Compositions, Functions, Providers, and GitOps delivery before they reach consumers.
- **Fast feedback**: prioritize local and cluster-level checks that surface errors in minutes.
- **Production-like behavior**: validate real reconciliation, real provider behavior, and real cloud-side resources.
- **Traceability**: treat Git as the source of truth for platform configuration, with visible reconciliation status.

## Scope

This strategy covers:

- Crossplane v2 XRDs (namespaced XRs), Compositions (pipeline mode), and Composition Functions
- Provider installation/health and ProviderConfig configuration
- An example **PostgreSQL** API package (`apis/v1alpha1/postgresql-databases/`)
- E2E testing patterns (KUTTL and optional Uptest)
- GitOps delivery via Flux and operational visibility via Crossview and Headlamp

---

## The 6 Testing Layers

We structure validation into six layers. Each layer has its own purpose, tools, and expected outputs.

| Layer | Name | Primary intent | Typical tools |
|------:|------|----------------|---------------|
| 0 | Local composition rendering | Validate XRD + Composition logic without a cluster | `crossplane render` |
| 1 | Cluster health + provider validation | Ensure Crossplane stack is stable; providers/functions Healthy; optionally validate managed resources | `kubectl`, webhook stabilization, health scripts, optional Uptest |
| 2 | Visual inspection & relationship debugging | Understand XR→MR graphs and composition outcomes | Crossview |
| 3 | In-cluster E2E tests | Validate reconciliation behavior in Kubernetes | KUTTL |
| 4 | Cloud-side verification | Confirm real Azure resources match intent | Azure CLI |
| 5 | GitOps deployment & monitoring | Continuous reconciliation, drift detection, and operational visibility | Flux, Headlamp (Flux plugin), optional Notifications/CI validation |

---

## Testing Pyramid (cost vs fidelity)

The pyramid below is a conceptual view of our recommended ordering:

```
             Layer 5: GitOps (Flux + Headlamp)
           (Continuous reconciliation & operations)
         ⏱️  Continuous | 🔺 Platform-wide
        /                                   \
   Layer 4: Cloud Verification (Azure CLI)
    (Azure control-plane reality checks)
   ⏱️  Minutes | 🔺 Few checks
  /                                   \
Layer 3: In-cluster E2E (KUTTL)
 (XR lifecycle + composed managed resources)
⏱️  20–40 min | 🔺 Some tests
 \                                   /
  Layer 2: Visual Inspection (Crossview)
   (XRD/Composition matching, XR→MR graph)
   ⏱️  Fast | 🔺 Many debugging actions
    \                                   /
     Layer 1: Cluster Health + Providers
      (webhooks, providers, functions, creds)
      ⏱️  Fast | 🔺 Many checks
        \                               /
         Layer 0: Local Render
          (XRD + Composition + example)
          ⏱️  < 1 sec | 🔺 Most checks

Legend:
🔺 = relative number of checks (wider = more)
⏱️  = feedback speed (bottom = fastest)
```

---

## When to Use Which Layer

- **Before committing composition changes**: Layer 0 (render) and (when needed) Layer 1 (cluster stability).
- **During active composition debugging**: Layer 2 (Crossview) to inspect matching, resources, and status conditions.
- **Before merging to main**: Layer 3 (KUTTL) plus Layer 4 checks for cloud-side correctness.
- **After merge / in environments**: Layer 5 (Flux) to ensure continuous reconciliation and drift detection.

---

## Recommended Development Workflow

This mirrors `dev.md` and is our preferred end-to-end flow:

1. **Change composition** (XRD/Composition/functions usage).
2. **Layer 0**: validate with `crossplane render` (fastest feedback).
3. **Apply via GitOps or apply to a cluster**.
4. **Layer 1**: run cluster health validation (providers/functions/webhooks stable).
5. **Layer 2**: inspect relationships and conditions (Crossview) when debugging.
6. **Layer 3**: run E2E suites (KUTTL).
7. **Layer 4**: verify Azure control-plane state (Azure CLI).
8. **Layer 5**: monitor continuous reconciliation and drift (Flux + Headlamp).

---

## Entry / Exit Criteria (Guidance)

### Layer 0 (local)
- **Entry**: editing XRD/Composition/Function usage
- **Exit**: `crossplane render` succeeds for relevant examples; output contains expected managed resources

### Layer 1 (cluster)
- **Entry**: applying providers/functions/apis to a cluster
- **Exit**: providers/functions report Healthy, Crossplane pods stable, no repeated webhook/timeout errors

### Layer 3 (E2E)
- **Entry**: stable cluster + valid provider config + test credentials present
- **Exit**: test suites succeed with reliable timeouts; cleanup completes

### Layer 5 (GitOps)
- **Entry**: manifests committed, Flux bootstrapped
- **Exit**: Flux resources Ready; drift managed; operational visibility available in Headlamp

---

## Pages for Each Layer

- Layer 0: `testing-layer-0-local-composition-rendering.md`
- Layer 1: `testing-layer-1-cluster-validation-and-health.md`
- Layer 2: `testing-layer-2-crossview-visual-inspection.md`
- Layer 3: `testing-layer-3-e2e-kuttl.md`
- Layer 4: `testing-layer-4-cloud-provider-verification.md`
- Layer 5: `testing-layer-5-gitops-flux-headlamp.md`

---

## Notes (Platform Engineering Perspective)

- **Prefer deterministic checks**: Rendering and health validation reduce noise before running slow E2E tests.
- **Design for debuggability**: standard labels, predictable naming, and explicit status fields make Crossview and CLI checks actionable.
- **Treat tests as part of the platform**: test suites, examples, and GitOps manifests are first-class artifacts, versioned and reviewed.

