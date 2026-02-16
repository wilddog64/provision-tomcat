# Plan: Stabilize Vagrant Test Kitchen Tests

**Objective:** To ensure the Vagrant-based Test Kitchen tests (`make test-win11`, `make test-upgrade-win11`) consistently pass in the CI pipeline, providing reliable local integration test coverage for the Ansible roles.

**Background:**
The Azure integration tests (`azure_integration` job) have been temporarily disabled due to authentication issues (ACG platform shift blocking Service Principal creation). This unblocks the main CI flow and allows us to focus on the core Vagrant-based testing that serves as a crucial fallback and local development verification mechanism. Previous attempts to stabilize the Ruby environment for Test Kitchen encountered various compatibility and permission issues, which have now been largely resolved for basic Bundler operations.

**Proposed Steps:**

1.  **Create a Dedicated `vagrant_tests` CI Job:**
    *   This new job will be added to `.github/workflows/ci.yml`.
    *   It will depend on the `lint` job.
    *   It will explicitly perform the necessary checkout operations (main repo, provision-java, windows-base, provision-windows-security).
    *   It will include the Python environment setup (venv, pip installs) as seen in `lint` and the former `azure_integration` job.
    *   It will include the Ruby environment setup (`bundle config set path 'vendor/bundle'`, `bundle install`) that currently works for `lint`.
    *   It will then execute `make test-win11` and `make test-upgrade-win11`.
    *   The `if` condition for this job will be set to run on pushes to `merge-main-into-azure-dev` (and potentially `main` or other relevant branches in the future), allowing for direct iteration and debugging.

2.  **Iterate and Debug Vagrant Test Failures:**
    *   Monitor the new `vagrant_tests` CI job.
    *   Address any failures related to Vagrant, VirtualBox, WinRM connectivity, Ansible execution, or Test Kitchen itself. This might involve:
        *   Reviewing `Vagrantfile` parameters (memory, CPU, network settings, WinRM tuning).
        *   Debugging Ansible playbooks or roles.
        *   Ensuring correct Test Kitchen parameters in `.kitchen.yml`.
        *   Resolving any remaining Ruby/gem incompatibilities specific to Test Kitchen execution.

3.  **Refine Vagrant Cleanup:** Ensure that `make vagrant-destroy` is always called, even on failure, to prevent orphaned VMs and disk lock issues on the runner.

4.  **Confirm Full Vagrant Test Coverage:** Verify that both `make test-win11` (initial provisioning) and `make test-upgrade-win11` (upgrade scenario) pass successfully.

**Expected Outcome:**
A fully stable and passing `vagrant_tests` CI job that reliably verifies the Ansible Tomcat provisioning roles on a local Windows Vagrant VM, providing a strong foundation for future development and platform integrations.

**Future Considerations:**
*   Revisit `azure_integration` when Azure authentication issues are resolved or better workarounds/tools are available.
*   Evaluate if the `vagrant_integration` job (as it currently stands in `ci.yml`) is still needed, or if the new `vagrant_tests` job covers its role.
