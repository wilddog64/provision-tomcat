# Zero-Downtime Upgrade Strategy

This document outlines how to extend the `provision-tomcat` role to run side-by-side Tomcat instances so you can smoke-test a new Java/Tomcat stack before repointing the `current` symlink. This approach works both in Test Kitchen (Vagrant) and on live Windows hosts.

## Goals

1. Install the new Tomcat/Java stack alongside the existing instance.
2. Start the candidate service on a temporary port without touching `C:/Tomcat/current`.
3. Run smoke tests from both inside the guest and from the controller/observer host.
4. Promote the candidate (flip symlink and service) only if every check succeeds; otherwise roll back cleanly.

## Variables to Introduce

Add the following variables (defaults shown) to `defaults/main.yml` so operators can enable the workflow per deployment:

```yaml
# Enable/disable candidate workflow
 tomcat_candidate_enabled: false

# Alternate port + service name used while testing the new build
 tomcat_candidate_port: 9080
 tomcat_candidate_service_name: "{{ tomcat_service_name }}Candidate"

# Optional: host used for controller-side checks
 tomcat_candidate_delegate: localhost
 tomcat_candidate_delegate_host: 127.0.0.1
 tomcat_candidate_delegate_connection: local
 tomcat_candidate_delegate_python: null
 tomcat_candidate_delegate_status_codes: [200, 404]
```

When `tomcat_candidate_enabled` is `false`, the role keeps its current behavior **unless** you explicitly set `tomcat_candidate_delegate`. Defining a delegate host acts as an implicit opt‑in for the candidate workflow because controller-side checks only make sense once the side-by-side service exists. You can further customize how Ansible reaches that delegate via `tomcat_candidate_delegate_connection` (defaults to `local`) and `tomcat_candidate_delegate_python` if the controller needs a specific interpreter path.

## Installation Flow

1. **Detect Upgrade** (already implemented)
   - If `tomcat_needs_upgrade` and the candidate workflow is enabled, skip removing `current` and go into “candidate” mode.

2. **Provision Candidate Service**
   - Extract the new Tomcat version into its versioned directory (already happens today).
   - Before creating/altering the main symlink, drop a `server.xml` override (or use `set_fact`) that changes the HTTP connector to `tomcat_candidate_port`.
   - Install a Windows service using `service.bat install //RS//{{ tomcat_candidate_service_name }}` with `CATALINA_HOME` pointing at the new directory.
   - Create a firewall rule allowing inbound TCP on `tomcat_candidate_port`.
   - Start the candidate service.

3. **Smoke Tests**
   - **Guest-side**: run `win_uri` (or `wait_for`) on the Windows host itself, targeting `http://localhost:{{ tomcat_candidate_port }}`. Fail fast if the response is not 200/404.
   - **Controller-side**: 
     - In Test Kitchen, add a forwarded port block to `.kitchen.yml` for the upgrade suite (e.g., guest 9080 → host 9080) so the controller can reach the candidate instance.
     - Add an Ansible task using `delegate_to: {{ tomcat_candidate_delegate }}` that executes `wait_for`/`uri` against `{{ tomcat_candidate_delegate_host }}:{{ tomcat_candidate_port }}`.
     - For production, set `tomcat_candidate_delegate_host` to the load balancer/CNAT IP that fronts the node.

   - If either check fails, stop the candidate service, remove its firewall rule, and leave the main instance untouched.

4. **Promotion**
   - Stop the existing Tomcat service and uninstall it (same logic as today).
   - Update `current` to point at the new directory.
   - Reconfigure the main Tomcat service (port 8080) to use the new path and start it.
   - Remove the temporary service, `server.xml` override, firewall rule, and (if desired) the candidate port forwarding entry.

5. **Cleanup**
   - Delete any candidate-specific configuration files.
   - Remove the candidate service using `service.bat remove //RS//{{ tomcat_candidate_service_name }}`.
   - Ensure only the main service is left running on port 8080.

## Test Kitchen Integration

In `.kitchen.yml` for the `upgrade` suite:

```yaml
driver:
  network:
    - ["forwarded_port", {guest: 8080, host: 8080, auto_correct: true}]
    - ["forwarded_port", {guest: 9080, host: 9080, auto_correct: true}]  # candidate
```

The default verifier already runs curl; extend it to hit the candidate port before converges promote the new build:

```yaml
verifier:
  name: shell
  command: |
    curl --connect-timeout 5 --max-time 10 -f http://localhost:9080 || exit 1
```

Alternatively, keep the verifier unchanged and rely solely on Ansible’s delegated `wait_for` task.

### Controller-side verification details

When `tomcat_candidate_delegate` (or `tomcat_candidate_enabled`) is set, `tasks/verify-candidate-controller.yml` runs two lookups from the controller:

1. `controller_port` polls the candidate port until the TCP handshake succeeds.
2. `controller_http` issues an HTTP request and requires a `200` or `404` response by default.

Both lookups are described in depth in `docs/plugins/CONTROLLER-LOOKUP-PLUGINS.md`. If you run Kitchen manually, make sure the 9080 port is forwarded before `kitchen create` so these controller probes can reach the guest.

### Leaving the candidate running for manual approval

By default, the role promotes and tears down the candidate service immediately after the checks succeed. Set `tomcat_candidate_manual_control: true` to skip the promotion/cleanup block so the candidate instance continues listening on port 9080. Once you have finished manual validation, rerun the role (or the Vagrant provisioner) with `tomcat_candidate_manual_control: false` to perform the promotion and remove the temporary service.

## Live Node Considerations

- Ensure your load balancer or network path exposes the candidate port temporarily so the controller-side check can reach it. You can restrict access to a jump host or monitoring node.
- Remember to close/remove the extra port once the upgrade completes to avoid leaving unused endpoints open.
- Use tags (e.g., `tomcat-candidate`) so you can run only the candidate-specific tasks when needed.

## Summary

All steps—installing the candidate service, testing it, promoting it, and cleaning up—can be scripted with Ansible. Test Kitchen simply provides a Windows VM and, if needed, forwarded ports for controller-side testing. Once these tasks are added to the role, you can perform zero-downtime upgrades consistently in CI and on real servers.
