# Plan: GitHub Actions Validation Workflow

## Context
The `provision-tomcat` repository requires a CI workflow to ensure code quality and stability. We aim to replicate the validation logic found in `provision-jenkins`, adapted for `provision-tomcat`'s specific dependencies and structure.

## Dependencies
`provision-tomcat` depends on the following roles (defined in `requirements.yml` or `tests/playbook.yml`):
1.  `provision-java` (Public)
2.  `windows-base` (Status: Potentially Private)
3.  `provision-windows-security` (Status: Potentially Private)

## Workflow Design
We will create a GitHub Actions workflow `.github/workflows/validation.yml` with a `lint` job.

### Job: Lint and Syntax Checks
**Runner:** `ubuntu-latest`

**Steps:**
1.  **Checkout `provision-tomcat`**: Standard checkout.
2.  **Checkout `provision-java`**: Use `actions/checkout` to clone into `roles/provision-java` (or a temporary dir included in `ANSIBLE_ROLES_PATH`).
    *   *Decision:* Clone to `roles/provision-java` to keep the workspace contained.
3.  **Setup SSH for Private Repos**: Use `webfactory/ssh-agent` to load deploy keys for private dependencies.
    *   Secrets required: `WINDOWS_BASE_DEPLOY_KEY`, `PROVISION_WINDOWS_SECURITY_DEPLOY_KEY` (or a shared `ANSIBLE_ROLES_DEPLOY_KEY`).
4.  **Checkout Private Dependencies**:
    *   Clone `windows-base` to `roles/windows-base`.
    *   Clone `provision-windows-security` to `roles/provision-windows-security`.
5.  **Setup Python**: Python 3.11.
6.  **Install Dependencies**:
    *   Pip: `requirements.txt` / `requirements-dev.txt` (if present, otherwise install `ansible-lint` directly).
    *   Ansible Collections: `make deps`.
7.  **Run Validation**:
    *   `make check`
    *   *Configuration:* Set `ANSIBLE_ROLES_PATH` environment variable to include the `roles/` directory so `ansible-lint` and `ansible-playbook --syntax-check` can find the dependencies.

### Secrets
To support private repositories, the following secrets will be documented as required on the repository:
- `WINDOWS_BASE_DEPLOY_KEY` (if `windows-base` is private)
- `PROVISION_WINDOWS_SECURITY_DEPLOY_KEY` (if `provision-windows-security` is private)

## Implementation Steps
1.  Create `.github/workflows/validation.yml`.
2.  Verify `make check` behavior locally with `ANSIBLE_ROLES_PATH` set.
3.  (Optional) Create a helper script `bin/install-deps` if complex logic is needed, but inline steps in YAML should suffice for now.
