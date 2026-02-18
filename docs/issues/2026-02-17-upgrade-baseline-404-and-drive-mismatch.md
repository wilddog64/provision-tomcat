# Issue: upgrade-baseline-win11 — 404 Download Failure and C:/D: Drive Mismatch

**Date:** 2026-02-17
**Branch:** azure-dev
**Triggered by:** `make test-upgrade-baseline-win11`
**Suite:** `upgrade-baseline-win11-baseline`

---

## Symptoms

### Error 1 — 404 Not Found on Tomcat Download
```
ERROR]: Task failed: Module failed: Error downloading
'https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.113/bin/apache-tomcat-9.0.113-windows-x64.zip'
to 'C:/temp/apache-tomcat-9.0.113.zip': The remote server returned an error: (404) Not Found.
Origin: tasks/install-Windows-tomcat.yml:126:7
```

### Error 2 — Wrong Install Drive
The download path shows `C:/temp/` when `defaults/main.yml` specifies `install_drive: "D:"`.

---

## Root Cause Analysis

### 404 Error

**File:** `tests/playbook-upgrade.yml` line 88

```yaml
tomcat_version: "{{ '9.0.112' if (upgrade_step | default(1) | int) == 1 else '9.0.113' }}"
```

The step-2 (upgrade) target is hardcoded to `9.0.113`. Apache's CDN (`dlcdn.apache.org`)
only hosts the **current** patch release per minor version. `9.0.113` has been superseded
by `9.0.115` and removed from the CDN. The role correctly constructs the URL from
`tomcat_version`, so an outdated version string produces a 404.

`defaults/main.yml` was already updated to `9.0.115` with the correct SHA-512 checksum,
but `playbook-upgrade.yml` bypasses that default by setting its own `set_fact`.

### Drive Mismatch (C: instead of D:)

**File:** `tests/playbook-upgrade.yml` lines 11–15

```yaml
vars:
  install_drive: "C:"                           # ← overrides role default
  tomcat_install_dir: "{{ install_drive }}/Tomcat"
  tomcat_temp_dir:    "{{ install_drive }}/temp"
  java_install_base_dir: "{{ install_drive }}/java"
  java_temp_dir:      "{{ install_drive }}/temp"
```

These playbook-level `vars` take precedence over `defaults/main.yml`
(`install_drive: "D:"`). The `upgrade-baseline` suite in `.kitchen.yml` does not pass
`install_drive: "D:"` as an `extra_var` to override them back, so the entire run uses C:.

**Contrast:** The `win11-disk` platform and `upgrade-candidate-aws-disk` suite both
explicitly pass `install_drive: "D:"` via `extra_vars`; the `upgrade-baseline` suite was
never updated to do the same.

---

## Affected Suite / Platform Matrix

| Suite                        | Platform         | Box                    | Drive needed | install_drive passed? |
|------------------------------|------------------|------------------------|--------------|-----------------------|
| `upgrade-baseline`           | `win11-baseline` | `windows11-tomcat112`  | D: (desired) | **No** ← bug          |
| `upgrade`                    | `win11`          | `stromweld/windows-11` | C: (no disk) | No (relies on default) |
| `downgrade`                  | `win11`          | `stromweld/windows-11` | C: (no disk) | No (relies on default) |
| `win11-disk` suites          | `win11-disk`     | `stromweld/windows-11` | D:           | Yes ✓                 |
| `upgrade-candidate-aws-disk` | `aws-minimal-win-disk` | AWS AMI          | D:           | Yes ✓                 |

---

## Required Fixes

### Fix 1 — Update target version in `tests/playbook-upgrade.yml` (line 88)

```yaml
# Before
tomcat_version: "{{ '9.0.112' if (upgrade_step | default(1) | int) == 1 else '9.0.113' }}"

# After
tomcat_version: "{{ '9.0.112' if (upgrade_step | default(1) | int) == 1 else '9.0.115' }}"
```

No checksum change needed: when `tomcat_version` is set by `set_fact`, the role's
`tomcat_checksum` from `defaults/main.yml` is already correct for `9.0.115`.

### Fix 2 — Resolve drive default conflict

**Option A (Minimal — targeted extra_var):**
Add `install_drive: "D:"` to the `upgrade-baseline` suite's `extra_vars` in `.kitchen.yml`.
This is a one-line change but does not fix the underlying conflict in the playbook.

**Option B (Preferred — align playbook default with role default):**
1. Change `playbook-upgrade.yml` line 11: `install_drive: "C:"` → `install_drive: "D:"`
2. Add `install_drive: "C:"` to the `upgrade` and `downgrade` suite `extra_vars` in
   `.kitchen.yml` (those use `win11` with no attached disk, so D: is unavailable).
3. Add `install_drive: "D:"` to `upgrade-baseline` suite `extra_vars`.

Option B is preferred because it makes the playbook consistent with `defaults/main.yml`
and forces drive intent to be explicit at the suite level.

### Prerequisite — Baseline box compatibility

The `windows11-tomcat112` box was built with Tomcat 9.0.112 installed. If it was built
with `install_drive: "C:"` (the old playbook default), then switching to D: for the
upgrade run means the new Tomcat install lands on a different drive than the baseline one.
Verify box state before applying Fix 2. If needed, rebuild the box using
`make pack-baseline-box` (or equivalent) with `install_drive: "D:"`.

---

## Status

- [ ] Fix 1: Update 9.0.113 → 9.0.115 in `playbook-upgrade.yml`
- [ ] Fix 2: Resolve C:/D: drive default (Option B preferred)
- [ ] Verify baseline box drive compatibility before applying Fix 2
- [ ] Re-run `make test-upgrade-baseline-win11` to confirm green
