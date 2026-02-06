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
```

Candidate mode installs the new bits on port 9080 and leaves the primary service (8080) stopped until promotion runs. Ansible already validates the candidate on 9080 (via `win_uri` plus the controller lookups) and then promotes it back to the primary port. If the controller verify step fails—or if the verifier keeps probing 9080 after promotion—the automation never confirms that the promoted service is live on 8080.

## Solution

Keep both ports forwarded so the Ansible candidate checks can hit 9080, but make the Kitchen verifier assert the final, promoted service on 8080:

```yaml
# .kitchen.yml
- name: upgrade-baseline
  driver:
    network:
      - ["forwarded_port", {guest: 8080, host: 8080, auto_correct: true}]
      - ["forwarded_port", {guest: 9080, host: 9080, auto_correct: true}]
  provisioner:
    extra_vars:
      tomcat_candidate_enabled: true
      tomcat_candidate_delegate: localhost
  verifier:
    name: shell
    command: |
      # Final promotion verification happens on port 8080 after candidate testing succeeds
      curl --connect-timeout 5 --max-time 10 -f http://localhost:8080 || \
      curl --connect-timeout 5 --max-time 10 http://localhost:8080 | grep -q "404"
```

## Understanding Candidate Mode

The zero-downtime workflow runs in two phases:

1. **Step 1**: Install the existing version (Tomcat 9.0.112) on port 8080.
2. **Step 2**: Deploy the candidate build (Tomcat 9.0.113) on port 9080 while the controller verifies it.
3. **Promotion**: After the controller checks succeed, stop the original service, promote the candidate to port 8080, and remove the sidecar.

By the time Test Kitchen reaches the verifier, the only service that should remain up is the promoted instance on port 8080.

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
