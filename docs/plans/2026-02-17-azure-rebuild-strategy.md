# Plan: Azure and Vagrant Stabilization Rebuild (2026-02-17)

**Goal:** Establish a clean, CI-verified integration pipeline for Azure and Vagrant by building on the stable `main` branch foundation and resolving specific authentication and transport blockers.

---

**Phase 1: Knowledge Preservation & Branch Reset [COMPLETED]**
*   Back up memory bank and diagnostics from the "messed up" merge attempt.
*   Rename the unstable `azure-dev` to `azure-dev-stale`.
*   Initialize a fresh `azure-dev` from the CI-verified `main` branch.

**Phase 2: Knowledge Integration & Planning [IN PROGRESS]**
*   Restore diagnostic data and memory bank.
*   Document the rebuild strategy (this file).
*   Update `memory-bank/activeContext.md` to reflect the new "Clean-Room" approach.
*   Commit initial state.

**Phase 3: CI/CD Modernization**
*   Update `.github/workflows/ci.yml` to use the Setup Composite Action.
*   Adopt the 3-job linear pipeline: `lint` -> `integration` -> `cleanup`.
*   Re-implement the `azure_integration` job with TAP-aware detection (`az account get-access-token` probe).
*   Configure a single, coordinated Vagrant fallback within the integration pipeline.

**Phase 4: Technical Fix Implementation**
*   **Azure**: Update `Makefile` with raw `az` CLI provisioning targets, replacing outdated Kitchen-Azure logic.
*   **Vagrant**: Implement `cmd /c exit 0` fix in `.kitchen.yml` to resolve the WinRM "true" blocker.
*   **Stability**: Implement timestamped VDI names in `Vagrantfile` to prevent disk collisions on the M2 runner.

**Phase 5: Verification & Delivery**
*   Verify branch via local `make check`.
*   Push to `azure-dev` to trigger CI verification.
*   Confirm Azure TAP-shift remediation and Vagrant fallback stability.
