# Security Hardening Decision Log (2026-02-14)

This document records key architectural and implementation decisions made during the security hardening process.

## [HIGH-1] Tomcat Download Checksum Verification
- **Decision:** Use SHA-512 for artifact verification.
- **Rationale:** Standard Apache release integrity practice.
- **Challenge:** Initial implementation failed due to `9.0.113` vs `9.0.115` mismatch in the CDN.
- **Resolution:** Explicitly updated version to `9.0.115` and verified the hash against official Apache `.sha512` files.
- **Technical Note:** Found that `ansible.windows.win_get_url` is sensitive to the `sha512:` prefix when `checksum_algorithm` is also set. Simplified to use just the hash value with the algorithm parameter.

## [HIGH-2/3] CI Execution Guards & Network Hardening
- **Decision:** Implement job-level `if` conditions and dynamic SG ingress rules.
- **Rationale:** Protect self-hosted runners from unauthorized fork code and minimize WinRM exposure.
- **Refinement:** Added `workflow_dispatch` to authorized triggers after initial feedback.
- **Implementation Detail:** Captured `RUNNER_IP` at start of AWS job and stored in `$GITHUB_ENV` to ensure consistent revocation during cleanup, even if the runner's public IP rotates.

## [HIGH-4] WinRM HTTPS Transition (Deferred)
- **Decision:** Reverted transition to port `5986` (HTTPS).
- **Rationale:** Standard AWS Windows AMIs do not have an HTTPS listener pre-configured. Transition caused immediate connectivity timeouts in Test Kitchen.
- **Future Work:** Will require a custom AMI with a self-signed cert or a bootstrap `user_data` script to enable the listener before WinRM attempts connection. Security is currently maintained via IP-restricted SG ingress.

## [HIGH-5] Log Security (no_log)
- **Decision:** Applied `no_log: true` to all service installation and user creation tasks.
- **Rationale:** Prevents service account passwords from appearing in CI logs or Ansible artifacts.

## [MED-4] Shutdown Port Binding
- **Decision:** Explicitly set `<Server port="..." address="127.0.0.1">` in `server.xml`.
- **Rationale:** Prevents remote unauthenticated shutdown of the Tomcat service while allowing local management scripts to function.
