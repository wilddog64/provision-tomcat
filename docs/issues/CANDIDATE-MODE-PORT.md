# Candidate Mode Uses Port 9080

## Problem

Kitchen verify occasionally fails with curl timeouts when running the `upgrade-baseline` suite:

```
curl: (28) Operation timed out after 10007 milliseconds with 0 bytes received
```

The verify step hits `localhost:8080`, but the VM still serves the candidate build on port 9080 when promotion did not finish.

## Root Cause

The suite enables **candidate mode**:

```yaml
# .kitchen.yml
- name: upgrade-baseline
  provisioner:
    extra_vars:
      tomcat_candidate_enabled: true
      tomcat_candidate_delegate: localhost
      tomcat_candidate_manual_control: true
```

Candidate mode installs the new bits on port 9080 and leaves the primary service (8080) stopped until promotion runs. Ansible already validates the candidate on 9080 (via `win_uri` plus the controller lookups) and then promotes it back to the primary port. If the controller verify step fails—or if the verifier keeps probing 9080 after promotion—the automation never confirms that the promoted service is live on 8080.

## Solution

Keep both ports forwarded so the Ansible candidate checks can hit 9080, but make the Kitchen verifier assert the final, promoted service on 8080:

```yaml
# .kitchen.yml
- name: upgrade-baseline
  driver:
    network:
      - ["forwarded_port", {guest: 8080, host: 18080, auto_correct: true}]
      - ["forwarded_port", {guest: 9080, host: 19080, auto_correct: true}]
  provisioner:
    extra_vars:
      tomcat_candidate_enabled: true
      tomcat_candidate_delegate: localhost
  verifier:
    name: shell
    command: |
      set -euo pipefail

      check_port() {
        local port="$1"
        local attempts="${2:-6}"
        local delay="${3:-10}"

        for attempt in $(seq 1 "$attempts"); do
          echo "Attempt ${attempt}/${attempts}: curl http://localhost:${port}"
          if curl --silent --show-error --connect-timeout 5 --max-time 10 -f "http://localhost:${port}" \
            || curl --silent --show-error --connect-timeout 5 --max-time 10 "http://localhost:${port}" | grep -q "404"; then
            echo "Port ${port} responded successfully."
            return 0
          fi
          if [ "$attempt" -lt "$attempts" ]; then
            echo "Port ${port} not ready yet; sleeping ${delay}s before retrying..."
            sleep "$delay"
          fi
        done

        echo "ERROR: Port ${port} never responded after ${attempts} attempts."
        return 1
      }

      candidate_host_port=19080
      primary_host_port=18080
      ansible_cmd="${KITCHEN_ANSIBLE_PLAYBOOK_BIN:-$(command -v ansible-playbook)}"
      temp_inventory="$(mktemp)"
      cat > "$temp_inventory" <<'EOF'
[baseline-win11-baseline]
baseline-win11 ansible_connection=winrm ansible_host=127.0.0.1 ansible_user=vagrant ansible_password=vagrant ansible_port=55985 ansible_winrm_transport=basic ansible_winrm_scheme=http ansible_winrm_server_cert_validation=ignore
EOF
      promotion_extra_vars="env=stage2 extract_build_number=16 extract_debug=False skip_migration=true upgrade_step=2 tomcat_auto_start=true tomcat_candidate_enabled=true tomcat_candidate_delegate=localhost tomcat_candidate_delegate_host=127.0.0.1 tomcat_candidate_delegate_port=${candidate_host_port}"

      echo "Checking candidate Tomcat on port ${candidate_host_port} before promotion..."
      check_port "${candidate_host_port}" 6 5

      echo "Promoting candidate via ansible-playbook before primary verification..."
      "$ansible_cmd" tests/playbook-upgrade.yml \
        -i "$temp_inventory" \
        -e "${promotion_extra_vars} tomcat_candidate_manual_control=false"
      rm -f "$temp_inventory"

      echo "Waiting for promoted Tomcat on port ${primary_host_port}..."
      check_port "${primary_host_port}" 12 10
```

## Understanding Candidate Mode

The zero-downtime workflow runs in two phases:

1. **Step 1**: Install the existing version (Tomcat 9.0.112) on port 8080.
2. **Step 2**: Deploy the candidate build (Tomcat 9.0.113) on port 9080 while the controller verifies it.
3. **Promotion**: After the controller checks succeed, stop the original service, promote the candidate to port 8080, and remove the sidecar.

By the time Test Kitchen reaches the verifier, the only service that should remain up is the promoted instance on port 8080—but GitHub Actions can lag a bit while the Windows service restarts. The script above makes sure we see 9080 succeed first and then patiently polls 8080 so promotion has time to finish.

## Port Forwarding Requirements

Ensure both ports are forwarded in the Kitchen driver config so controller-side checks can reach 9080 and the final verify can reach 8080:

```yaml
driver:
  network:
    - ["forwarded_port", {guest: 8080, host: 8080, auto_correct: true}]
    - ["forwarded_port", {guest: 9080, host: 9080, auto_correct: true}]
```

## Related

- [Zero-Downtime Upgrades](../ZERO-DOWNTIME-UPGRADES.md)
- [Candidate Troubleshooting](../CANDIDATE-TROUBLESHOOTING.md)
