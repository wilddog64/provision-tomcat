# provision-java regex_search Crash

## Problem

During Windows provisioning, the playbook fails at "Parse installed Java version" with:

```
fatal: [default]: FAILED! => {
  "msg": "The task includes an option with an undefined variable...
   'NoneType' object has no attribute 'group'"
}
```

Or in verbose mode:

```
An exception occurred during task execution...
AttributeError: 'NoneType' object has no attribute 'group'
```

## Root Cause

The `provision-java` role uses Jinja2's `regex_search` filter to parse Java version output:

```yaml
- name: Parse installed Java version
  set_fact:
    installed_java_version: >-
      {{ java_version_output.stderr | regex_search('openjdk version "([0-9.]+)"', '\\1') }}
```

**Problems with this approach:**

1. **regex_search returns None when no match** - If the pattern doesn't match, the filter returns `None`, and accessing `\\1` on `None` causes the crash.

2. **Microsoft JDK output differs** - Microsoft's JDK prints `version "21.0.x"` instead of `openjdk version "21.0.x"`.

3. **stdout vs stderr** - Different JDK vendors output version info to different streams.

## Solution

### Option 1: Hotpatch in CI (Temporary)

For GitHub Actions, hotpatch the provision-java role after checkout:

```yaml
- name: Hotpatch provision-java
  run: |
    python3 -c "
    import os
    fpath = 'roles/provision-java/tasks/install-Windows-java.yml'
    if os.path.exists(fpath):
        with open(fpath, 'r') as f: content = f.read()

        # 1. Use regex_findall instead of regex_search (returns list, not None)
        content = content.replace('regex_search', 'regex_findall')

        # 2. Match any 'version' not just 'openjdk version'
        content = content.replace('openjdk version', 'version')

        # 3. Remove backreference (regex_findall returns list)
        content = content.replace(\", '\\\\1'\", \"\")

        # 4. Check both stdout and stderr
        content = content.replace('java_version_output.stderr',
                                  '(java_version_output.stdout + java_version_output.stderr)')

        with open(fpath, 'w') as f: f.write(content)
        print('Hotpatched provision-java')
    "
```

### Option 2: Fix in provision-java (Permanent)

Update the task in `provision-java/tasks/install-Windows-java.yml`:

```yaml
- name: Parse installed Java version
  ansible.builtin.set_fact:
    installed_java_version: >-
      {{ (java_version_output.stdout + java_version_output.stderr)
         | regex_findall('version "([0-9.]+)"')
         | first | default('unknown') }}
  when: java_version_output.rc == 0
```

**Why this works:**

| Filter | No Match Behavior | Usage |
|--------|-------------------|-------|
| `regex_search` | Returns `None` | Crashes on backreference |
| `regex_findall` | Returns `[]` (empty list) | Safe with `first \| default()` |

## Verification

After fix, the task should handle both:

**OpenJDK output:**
```
openjdk version "21.0.2" 2024-01-16
```

**Microsoft JDK output:**
```
openjdk version "21.0.2" 2024-01-16 LTS
```

## Related

- This issue was discovered during CI integration testing
- The fix has been merged to `provision-java` main branch
- For CI, the hotpatch is applied as a workaround until all environments use the fixed version
