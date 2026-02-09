# Candidate Upgrade Troubleshooting

A few recurring problems surfaced while shaking down the zero-downtime (candidate) workflow. Capture them here so we can triage log output quickly the next time a Kitchen run fails.

## 1. Candidate block never runs (no 9080 in logs)

**Symptom:** `scratch/candidate-upgrade.log` contains only `skip_reason: "tomcat_candidate_active | default(false) | bool"` entries for every candidate task (no edits to `server.xml`, no `win_wait_for`/`win_uri`, and `rg 9080 scratch/candidate-upgrade.log` returns nothing).

**Causes/Fixes:**

1. **`tomcat_candidate_active` stayed false because no upgrade was detected.** This happens when the VM already has the target Tomcat/JDK installed (e.g., rerunning `make test-upgrade-candidate-win11` without cleanup). Fix: `make candidate-cleanup-win11` to destroy the VM, then rerun the candidate workflow so step 1 installs the old version before upgrading.
2. **`.kitchen.local.yml` still forced `upgrade_step: 2` for step 1.** If that file lingers from a previous run, Kitchen applies the override during the initial converge and `tomcat_needs_upgrade` never flips true. Fix: remove `.kitchen.local.yml` before step 1 (the Makefile does this automatically now).
3. **Port 9080 wasn’t forwarded when the VM was created.** VirtualBox only opens NAT rules during `kitchen create`. The Makefile now creates `.kitchen.local.yml` with the port mappings before step 1; if you run Kitchen manually, do the same before `kitchen create upgrade-win11`.
4. **`tomcat_candidate_delegate` was set, but the play still blocked on `tomcat_needs_upgrade`.** We now treat `tomcat_candidate_enabled` or `tomcat_candidate_delegate` as an explicit request to run the candidate install regardless of the existing version. Ensure you’re on the latest `tasks/install-Windows-tomcat.yml` before testing.

Check the log for `tomcat_candidate_active: true` before the candidate block. If it’s false, the sidecar service will never start and you won’t see port 9080.

## 2. Controller `wait_for` fails with `ConvertFrom-Json`

**Symptom:** Ansible raises `Module result deserialization failed: No start of json char found` and PowerShell logs `ConvertFrom-Json` errors.

**Cause:** Delegated tasks inherited `ansible_connection=winrm` (from Kitchen extra vars) and tried to run the controller checks over PSRP.

**Fix:** Controller wait/HTTP steps now run via custom lookup plugins directly on the controller. Update to the latest `tasks/verify-candidate-controller.yml` plus `lookup_plugins/controller_port.py` and `controller_http.py`.

## 3. Controller wait loops forever even though Windows-side checks pass

**Symptom:** The Windows host started `Tomcat9Candidate` and `win_uri` against `http://localhost:9080` succeeded, but the controller `wait_for` retries 24 times.

**Cause:** Port forwarding wasn’t in place (see issue #1) or the controller can’t route to the VM (wrong delegate host/port).

**Fix:** Make sure `.kitchen.local.yml` contains the 9080 mapping before `kitchen create`. If you’re testing against a different environment, set `tomcat_candidate_delegate_host` to the reachable IP/hostname and adjust `tomcat_candidate_delegate_connection`/`_python` as needed.

## 4. Miscellaneous gotchas

- Unicode checkmarks (`✓ ... complete!`) made it hard to search logs; we removed them.
- `tomcat_candidate_delegate_python` should be left undefined unless you need a specific interpreter path; don’t set it to `null`.
- Always run `make candidate-cleanup-win11` between full test runs to avoid stale `.kitchen.local.yml` and VirtualBox state.
- Use `tomcat_candidate_manual_control: true` if you want to keep the candidate service running on port 9080 for manual tests. Remember to rerun the playbook with that flag set to `false` (or omitted) when you’re ready to promote and clean up.

Update this doc as new edge cases are found.
