# Active Context

## Current Session Objective
Stabilize the AWS integration testing pipeline, achieving parity with the successfully completed Azure stabilization.

## Current State Snapshot
- Azure CI pipeline is fully stabilized and passing on the `azure-dev` branch.
- Switched to the `aws-dev` branch to begin AWS stabilization.
- Created `docs/plans/AWS-SANDBOX-STABILIZATION.md` outlining the technical strategy.

## What Was Done
1. Scanned core repo docs and code paths (`README.md`, defaults, tasks, Kitchen config, Makefile, upgrade and plugin docs).
2. Confirmed operational architecture:
   - Windows-focused Tomcat provisioning role
   - symlink-based version management
   - candidate (side-by-side) verification and promotion workflow
   - controller-side health checks via lookup plugins
3. Captured security posture with secret-store guidance, including HashiCorp Vault alignment.
4. Documented constraints where `.clinerules` expectations (k3s/ArgoCD references) exceed currently implemented repository scope.

## Why These Decisions Were Made
- **Why initialize all memory files now:** `.clinerules` mandates memory-bank as primary cross-agent state and requires initialization when missing.
- **Why include `progress.md` in addition to the four required files:** `.clinerules` explicitly requires real-time updates to both `activeContext.md` and `progress.md` after changes/tests.
- **Why document k3s/ArgoCD as guardrails instead of implementation details:** repository scan found no direct k3s/ArgoCD assets; documenting this avoids inventing architecture while preserving policy intent.
- **Why emphasize secret lookup patterns:** `.clinerules` forbids plaintext secrets and requires Vault-oriented compliance, which aligns with existing service-account documentation.

## Immediate Next Actions
- Keep this file as the first read before any future task.
- On each subsequent change/test:
  - update this file with what changed and why,
  - update `progress.md` checklist status.

## Risks / Follow-ups
- If future scope adds Kubernetes/GitOps components (k3s/ArgoCD), `systemPatterns.md` must be expanded from guardrails to concrete operational flows.
- If this role is integrated into e-commerce shopping-cart infrastructure, API/integration contracts should be documented explicitly (currently out of direct repo scope).