# Provider Plugin Makefile Refactor

**Branch:** `aws-dev`
**Status:** PLANNED
**Goal:** Extract cloud-specific `define` blocks from the 651-line Makefile into a
provider plugin layout (`scripts/providers/{aws,azure,gcp}/`) so each cloud is
self-contained, testable, and independently maintainable.

---

## Problem

The Makefile currently embeds all AWS-specific infrastructure logic as `define` macros:

| Define / Target | Lines | What it does |
|---|---|---|
| `discover-aws-resources` | 105–142 | Discovers subnet, SG, AMI via AWS CLI |
| `load_aws_discovery_env` | 143–154 | Parses discovery output into env vars |
| `authorize_local_aws_test_ingress` | 155–167 | Opens SG ports 5985/8080/9080 for runner IP |
| `revoke_local_aws_test_ingress` | 168–176 | Revokes the above |
| `load_upgrade_test_env` | 177–230 | Resolves Tomcat download URLs + SHA512 checksums |
| `promote_aws_candidate` | 231–254 | Builds WinRM inventory, runs upgrade playbook, smoke-tests |

Problems with this layout:
- **Untestable** — logic only runs via `make`; no standalone execution
- **No reuse** — CI cannot call individual steps without invoking Make
- **Azure is a stub** — `test-azure-provision-tomcat` is one line; Azure infrastructure management doesn't exist yet
- **GCP is unplanned** — no structure to add it without further Makefile bloat
- **Python one-liner** in `promote_aws_candidate` is unreadable and unmaintainable

---

## Solution — Provider Plugin Layout

```
scripts/
  providers/
    aws/
      discover.sh          # Prints KEY=VALUE: SUBNET_ID, SG_ID, AMI_ID, AZ, REGION
      ingress.sh           # Usage: ingress.sh authorize|revoke
      promote-candidate.sh # Reads Kitchen state, runs upgrade playbook, smoke-tests
      build-inventory.py   # Extracted from promote_aws_candidate Python one-liner
    azure/
      discover.sh          # (stub) Azure resource group, vnet, NSG discovery
      ingress.sh           # (stub) NSG rule add/remove
      promote-candidate.sh # (stub) Azure candidate promotion
    gcp/
      discover.sh          # (stub) VPC, firewall, image discovery
      ingress.sh           # (stub) Firewall rule add/remove
      promote-candidate.sh # (stub) GCP candidate promotion
  common/
    resolve-tomcat.sh      # Provider-agnostic: Tomcat URL + SHA512 resolution
    check-credentials.sh   # Delegates to provider-specific auth check
```

---

## Provider Interface Contract

Every provider must implement these three scripts with these exact behaviors:

### `scripts/providers/<provider>/discover.sh`
- No arguments
- Prints `KEY=VALUE` lines to stdout (one per line)
- Required keys: `SUBNET_ID`, `SG_ID`, `AMI_ID` (or `IMAGE_ID` for GCP/Azure), `AZ`, `REGION`
- Exits non-zero with a message to stderr on failure
- Callers use: `eval $(scripts/providers/${PROVIDER}/discover.sh)`

### `scripts/providers/<provider>/ingress.sh`
- Argument: `authorize` or `revoke`
- Reads `RUNNER_IP`, `SG_ID`, `REGION` from environment
- Opens/closes ports 5985, 8080, 9080 for `$RUNNER_IP/32`
- Idempotent — `authorize` on existing rule is not an error

### `scripts/providers/<provider>/promote-candidate.sh`
- Reads Kitchen state from `.kitchen/` directory
- Reads upgrade env vars from environment (`UPGRADE_JAVA_*`, `UPGRADE_TOMCAT_*`)
- Runs `ansible-playbook tests/playbook-upgrade.yml` against the candidate
- Smoke-tests the promoted primary

---

## Makefile After Refactor

The dispatcher shrinks to:

```makefile
PROVIDER ?= aws

test-provision-tomcat: check-credentials update-roles
    @eval $$(scripts/providers/$(PROVIDER)/discover.sh) && \
    eval $$(scripts/common/resolve-tomcat.sh) && \
    RUNNER_IP=$${LOCAL_AWS_RUNNER_IP:-$$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')} && \
    export RUNNER_IP && \
    scripts/providers/$(PROVIDER)/ingress.sh authorize && \
    trap 'scripts/providers/$(PROVIDER)/ingress.sh revoke' EXIT && \
    KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) test default-$(PROVIDER)-minimal-win-disk && \
    scripts/providers/$(PROVIDER)/promote-candidate.sh

test-upgrade-candidate: check-credentials sync-$(PROVIDER) update-roles
    @eval $$(scripts/providers/$(PROVIDER)/discover.sh) && \
    eval $$(scripts/common/resolve-tomcat.sh) && \
    RUNNER_IP=$${LOCAL_AWS_RUNNER_IP:-$$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')} && \
    export RUNNER_IP && \
    scripts/providers/$(PROVIDER)/ingress.sh authorize && \
    trap 'scripts/providers/$(PROVIDER)/ingress.sh revoke' EXIT && \
    scripts/providers/$(PROVIDER)/promote-candidate.sh
```

Old targets (`test-aws-provision-tomcat`, `test-aws-upgrade-candidate`,
`test-azure-provision-tomcat`) become thin aliases:

```makefile
test-aws-provision-tomcat:
    $(MAKE) test-provision-tomcat PROVIDER=aws

test-azure-provision-tomcat:
    $(MAKE) test-provision-tomcat PROVIDER=azure

test-aws-upgrade-candidate:
    $(MAKE) test-upgrade-candidate PROVIDER=aws
```

---

## Phase Plan

### Phase 1 — AWS extraction (this spec, Codex task)
Extract the four AWS `define` blocks into `scripts/providers/aws/`:
- `discover.sh` from `discover-aws-resources` + `load_aws_discovery_env`
- `ingress.sh` from `authorize_local_aws_test_ingress` + `revoke_local_aws_test_ingress`
- `promote-candidate.sh` + `build-inventory.py` from `promote_aws_candidate`
- `scripts/common/resolve-tomcat.sh` from `load_upgrade_test_env`
- Update Makefile to use dispatcher pattern; keep old target aliases

### Phase 2 — Azure stubs (separate task)
Create `scripts/providers/azure/` with stub scripts that exit with a clear
"not yet implemented" message. Wire `test-azure-provision-tomcat` to the dispatcher.

### Phase 3 — GCP stubs (separate task)
Same pattern as Phase 2 for GCP.

---

## Before You Start

- Branch: `aws-dev`
- Read this spec in full before touching any file
- Read these files before editing:
  - `Makefile` lines 94–330 (all `define` blocks and AWS targets)
  - `scripts/setup.sh` (check if any logic should move to `common/`)
- `shellcheck` must pass on all new `.sh` files: `shellcheck scripts/providers/aws/*.sh scripts/common/*.sh`
- Do NOT move `resolve_tomcat_release` bash function — keep it in `resolve-tomcat.sh` as a sourced function
- Existing targets (`test-aws-provision-tomcat`, `test-aws-upgrade-candidate`, `test-aws-upgrade-candidate-latest`) must remain functional — add aliases, do not delete

---

## Definition of Done — Phase 1

- [ ] `scripts/providers/aws/discover.sh` — standalone, executable, `shellcheck` clean
- [ ] `scripts/providers/aws/ingress.sh authorize|revoke` — standalone, executable, `shellcheck` clean
- [ ] `scripts/providers/aws/promote-candidate.sh` — standalone, executable, `shellcheck` clean
- [ ] `scripts/providers/aws/build-inventory.py` — Python inline extracted; `python3 -m py_compile` clean
- [ ] `scripts/common/resolve-tomcat.sh` — standalone, executable, `shellcheck` clean
- [ ] `scripts/providers/azure/` — stub directory with `discover.sh`, `ingress.sh`, `promote-candidate.sh` each printing "not yet implemented" and exiting 1
- [ ] Makefile `define` blocks removed; replaced by dispatcher + aliases
- [ ] `make test-aws-provision-tomcat` and `make test-aws-upgrade-candidate` still parse without error (`make --dry-run`)
- [ ] Committed on `aws-dev` with message:
  `refactor(makefile): extract provider defines into scripts/providers/ plugin layout`
- [ ] SHA reported; pushed to origin before reporting done

## What NOT to Do

- Do NOT create a PR
- Do NOT skip pre-commit hooks (`--no-verify`)
- Do NOT change any Ansible playbook, role, or Kitchen YAML
- Do NOT commit to `main`
- Do NOT rename or remove existing Make targets — only add aliases and redirect to dispatcher
