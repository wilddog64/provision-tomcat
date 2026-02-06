# Candidate Mode Uses Port 9080

## Problem

Kitchen verify step fails with curl timeout when testing upgrade-baseline suite:

```
curl: (28) Operation timed out after 10007 milliseconds with 0 bytes received
```

The verifier tries to connect to `localhost:8080` but gets no response.

## Root Cause

The `upgrade-baseline` suite uses **candidate mode**:

```yaml
# .kitchen.yml
- name: upgrade-baseline
  provisioner:
    extra_vars:
      tomcat_candidate_enabled: true
      tomcat_candidate_delegate: localhost
```

In candidate mode:

| Service | Port | Purpose |
|---------|------|---------|
| Primary Tomcat | 8080 | Original installation (may be stopped during upgrade) |
| Candidate Tomcat | **9080** | New version being tested |

The verifier was checking port 8080, but the candidate service runs on **port 9080**.

## Solution

Update the verifier to check the correct port for candidate mode:

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
      # Check candidate Tomcat on port 9080 (candidate mode uses 9080)
      curl --connect-timeout 5 --max-time 10 -f http://localhost:9080 || \
      curl --connect-timeout 5 --max-time 10 http://localhost:9080 | grep -q "404"
```

## Understanding Candidate Mode

The candidate workflow allows zero-downtime upgrades:

1. **Step 1**: Install base version (Tomcat 9.0.112) on port 8080
2. **Step 2**: Install candidate version (Tomcat 9.0.113) on port 9080
3. **Verify**: Test candidate on port 9080
4. **Promote**: Stop primary, promote candidate to port 8080
5. **Cleanup**: Remove old version

During step 2, only port 9080 serves the new version.

## Port Forwarding Requirements

Ensure both ports are forwarded in the Kitchen driver config:

```yaml
driver:
  network:
    - ["forwarded_port", {guest: 8080, host: 8080, auto_correct: true}]
    - ["forwarded_port", {guest: 9080, host: 9080, auto_correct: true}]
```

## Related

- [Zero-Downtime Upgrades](../ZERO-DOWNTIME-UPGRADES.md)
- [Candidate Troubleshooting](../CANDIDATE-TROUBLESHOOTING.md)
