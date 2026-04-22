# AWS candidate latest-version live test findings

## What was tested / attempted

- Determined latest upstream versions at test time:
  - Tomcat 9 latest: `9.0.117`
  - Java latest LTS: `25`
- Attempted a live AWS candidate workflow using:
  - baseline: Java `21` + Tomcat `9.0.115`
  - candidate: Java `25` + Tomcat `9.0.117`
- Used AWS disk-backed Windows suite behavior as the baseline for the exercise.
- Cleaned up the AWS instance and temporary security group ingress after the run.

## Actual output

Key discovery output:

```text
Latest Tomcat 9: 9.0.117
Latest Java LTS: 25
AWS_REGION=us-west-2
AWS_AMI_ID=ami-0b15fb428fbc526fe
AWS_SECURITY_GROUP_ID=sg-0d89881a3d8fd4fdb
RUNNER_IP=216.9.30.23
```

First live blocker (old Tomcat URL no longer on `dlcdn`):

```text
Error downloading 'https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115-windows-x64.zip'
to 'D:/temp/apache-tomcat-9.0.115.zip': The remote server returned an error: (404) Not Found.
```

Second live blocker (latest Tomcat checksum mismatch when switching to archive URL):

```text
The checksum for https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.117/bin/apache-tomcat-9.0.117-windows-x64.zip
did not match
'77e79950cc7fd1b00888fb351e542ec8235c071e5a021b980b5dabc3023a23bdee42beccaedf529c530c8ec85bab13d83662b8df22ac3dc596f295526375f5d5',
it was
'f8b6e8ca5d703fbab508cf09e0e9589f556a80c1ac5e5d3b62ef2e643e7e4598c20b4b6ef9e04a280827dc21199d48d73fa42608396971c5263adee5242d0084'
```

Candidate-stage success after temporary runtime overrides:

```text
Candidate Tomcat reachable on 9080
```

Promotion-stage gap:

```text
[WARNING]: Unable to parse /Users/cliang/src/gitrepo/personal/ansible/provision-tomcat/.kitchen/ansible_inventory/ansible_inventory.ini as an inventory source
[WARNING]: No inventory was parsed, only implicit localhost is available
[WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'

PLAY [Test Tomcat/Java upgrade scenarios] **************************************
skipping: no hosts matched
```

Observed end state from the live run:

```text
Tomcat 9.0.117 installed at D:/Tomcat/current. Service: Tomcat9 (started automatically)
Installation complete for upgrade step 2
Tomcat version: 9.0.117
Java version: 25
```

## Root cause

- Upgrade version selection is not a first-class input; it is hardcoded in `tests/playbook-upgrade.yml`.
- Default Tomcat download behavior assumes all tested versions are still available on `dlcdn.apache.org`.
- Default checksum behavior is pinned to the repository default Tomcat release, not the requested upgrade target.
- AWS candidate promotion is not fully productized as a supported target with a reliable inventory handoff.

## Recommended follow-up

- Implement configurable old/new Java and Tomcat version inputs in `Makefile` and `tests/playbook-upgrade.yml`.
- Support explicit `tomcat_download_url` and `tomcat_checksum` overrides for archived releases.
- Add a supported AWS promotion path that uses a valid inventory source.
- Use `docs/plans/2026-04-22-configurable-upgrade-version-targets.md` as the implementation spec.

## Full log

- `scratch/aws-candidate-latest-retry3-20260421-200241.log`
