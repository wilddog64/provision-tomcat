# To-Do: Remediate ACG Azure Sandbox Access Issues

**Date Identified:** 2026-02-16

**Problem:**
The Azure integration tests are currently disabled due to authentication failures when attempting to interact with the ACG (Azure Cloud Governance) sandbox environment.

*   **Error Code:** `AADSTS130507`
*   **Root Cause:** An ACG platform shift to a TAP (Temporary Access Pass)/User Account model has been implemented. This change fundamentally blocks the creation of Service Principals (SPs) for automated authentication in the traditional manner, resulting in "Insufficient privileges" errors.
*   **Impact:** Automated Azure integration tests using Service Principals are currently infeasible, leading to the temporary disabling of the `azure_integration` CI job to unblock overall CI progress.

**Current Status:**
*   `azure_integration` job in `.github/workflows/ci.yml` is set to `if: false`.
*   Focus has shifted to stabilizing Vagrant-based Test Kitchen tests.

**Possible Solutions / Future Investigation:**

When revisiting this issue, consider the following approaches:

1.  **Engage ACG Platform Owners:**
    *   Understand the new recommended authentication mechanism for automated CI/CD processes within the ACG framework.
    *   Inquire about any exceptions or alternative methods for Service Principal creation/usage for non-interactive CI/testing scenarios.

2.  **Explore Alternative Azure Authentication Methods:**
    *   **Managed Identities:** Investigate if Azure Managed Identities can be leveraged by the GitHub Actions self-hosted runner for authentication to Azure resources. This would require runner-side configuration and potentially updates to `kitchen-azure`.
    *   **Workload Identity Federation (GitHub Actions):** Research if GitHub's native Workload Identity Federation (which allows GitHub Actions to access Azure resources without long-lived secrets) is compatible with the ACG platform and the `kitchen-azure` driver.
    *   **Device Code Flow / User Interaction:** While generally not ideal for unattended CI, explore if a manual step can be integrated for initial authentication, with tokens cached for subsequent runs (less ideal, high friction).

3.  **Update `kitchen-azure` (or find an alternative driver):**
    *   The `kitchen-azure` gem (version `0.1.0`) is very old and requires `test-kitchen ~> 1.2`. If newer Azure authentication methods are identified, `kitchen-azure` might need an upgrade to a newer version (if one exists) or replacement with a more modern Test Kitchen driver for Azure that supports the new ACG authentication.

4.  **Simplify Azure Test Scope:**
    *   If full provisioning testing is impossible, consider if a "smoke test" or basic connectivity test against Azure could be implemented that doesn't require Service Principal creation, e.g., verifying basic Azure CLI access.

5.  **Re-evaluate Need for Direct Azure VM Integration:**
    *   Given current Ansible usage is against VMWare *within* Azure, determine if direct `kitchen-azure` integration with Azure VMs is truly necessary, or if the VMWare-specific testing should be prioritized using other means.

**Priority:** Low (for immediate action), High (for future strategic planning).
