1. [DONE] Troubleshoot Azure login failure (ACG platform change).
2. [DONE] Harden Vagrant/WinRM fallback stability (Envelope size, timeouts, pauses, memory, concurrent ops).
3. [DONE] Fix CI workflow triggers and ERB parsing.
4. [DONE] Diagnose and fix Ruby environment issues for linting.
5. [DONE] Temporarily disable azure_integration job.
6. [DONE] Post-mortem analysis of azure-dev branch failure.
7. [IN PROGRESS] Clean-room rebuild of azure-dev from main.
8. [TODO] Fix WinRM "true" error (override readiness command with `cmd /c exit 0`).
9. [TODO] Pin Ruby 3.3.x in CI to eliminate compatibility spiral.
10. [TODO] Implement 2-job CI pipeline (lint + Vagrant integration).
11. [TODO] Clean up stale branches (merge-main-into-azure-dev, copilot/sub-pr-13-again, azure-dev-stale).
12. [TODO] Instruct user to update Copilot firewall allowlist.
13. [DEFERRED] Revisit Azure TAP auth when ACG credential model stabilizes.
14. [DEFERRED] Port raw `az` CLI provisioning to Makefile.
