# Layer 4 — Cloud-Side Verification (Azure CLI)

## Purpose

Layer 4 verifies that the desired state expressed in Kubernetes results in the **correct cloud-side reality**.

This layer is intended to answer:

- “Did Azure actually create the PostgreSQL server and database we intended?”
- “Do the resulting resources match naming, location, SKU, and configuration requirements?”
- “Are we confident that provider reconciliation represents real-world success?”

## Why it matters

Kubernetes conditions can be misleading if:

- a provider reports intermediate states that look healthy but do not match intent
- a resource exists but is misconfigured (SKU, region, name, tags)
- the cluster has stale credentials/permissions that intermittently fail

Cloud verification closes the loop by checking the source-of-truth system: the cloud control plane.

## Tools and methods

- **Azure CLI**
  - validate existence and properties of resources created by Crossplane
  - monitor progress while a test is running

Note: In our strategy (as defined in `dev.md`), **Uptest is an optional Layer 1 provider validation technique**, not a Layer 4 tool.

In `dev.md` we show patterns like:

- watch Azure resource group: `az resource list --resource-group ...`
- verify PostgreSQL Flexible Server and DB objects (server show + db show)

## What you typically verify (PostgreSQL example)

- The resource group exists and contains the expected resources.
- A PostgreSQL Flexible Server exists with the derived server name.
- A database exists on that server with the intended external name.

## What “good” looks like (guidance)

- Azure resources exist and match the intent expressed in the XR parameters (location, names, sizing).
- Reconciliation converges without repeated error churn in provider logs.
- Deletion tests remove cloud resources as expected (no orphans).

## Common failure modes (Azure)

- **Subscription resource provider not registered**
  - symptom: failures indicating `Microsoft.DBforPostgreSQL` not registered
  - action: register the provider namespace once per subscription

- **Name constraints**
  - symptom: server name invalid or already taken
  - action: change the XR name (and therefore derived server name), re-run

- **Permissions / credentials**
  - symptom: authorization failures or AAD auth errors
  - action: validate Service Principal credentials and ProviderConfig secret formatting

## Relationship to other layers

- Layer 4 is usually executed alongside Layer 3 (E2E) for high confidence.
- Layer 4 is especially important for platform changes that affect security, compliance, cost, or lifecycle controls.

## Practical checks (examples referenced in `dev.md`)

- Watch the resource group during test runs:
  - `az resource list --resource-group <rg> --output table`
- Validate the PostgreSQL server exists:
  - `az postgres flexible-server show --resource-group <rg> --name <server> --output none`
- Validate the database exists:
  - `az postgres flexible-server db show --resource-group <rg> --server-name <server> --database-name <db> --output none`

