SHELL := /bin/bash

ifeq ($(filter KEEP,$(MAKECMDGOALS)),KEEP)
KEEP := 1
MAKECMDGOALS := $(filter-out KEEP,$(MAKECMDGOALS))
endif
export DISABLE_BUNDLER_SETUP := 1

ifeq ($(OS),Windows_NT)
  DEFAULT_KITCHEN_YAML := .kitchen-win.yml
else
  DEFAULT_KITCHEN_YAML := .kitchen.yml
endif

KITCHEN_YAML ?= $(DEFAULT_KITCHEN_YAML)
RBENV_BIN := $(shell command -v rbenv 2>/dev/null)
ifdef RBENV_BIN
  export RBENV_VERSION := $(shell cat .ruby-version 2>/dev/null)
  KITCHEN_CMD ?= rbenv exec bundle exec kitchen
else
  KITCHEN_CMD ?= bundle exec kitchen
endif

PLATFORMS := win11 win11-disk ubuntu-2404 rockylinux9 aws-minimal-win aws-minimal-win-disk
SUITES := default latest idempotence

# Version variables for upgrade/downgrade testing
JAVA_OLD_VERSION ?= 17
JAVA_NEW_VERSION ?= 21
TOMCAT_OLD_VERSION ?= 9.0.112
TOMCAT_NEW_VERSION ?= 9.0.113
TOMCAT_OLD_DOWNLOAD_URL ?=
TOMCAT_NEW_DOWNLOAD_URL ?=
TOMCAT_OLD_CHECKSUM ?=
TOMCAT_NEW_CHECKSUM ?=

.DEFAULT_GOAL := help

# ============================================================================ 
# Validation Targets
# ============================================================================ 
.PHONY: lint
lint: deps
	@echo "Running ansible-lint..."
	ansible-lint --offline .

.PHONY: syntax
syntax: deps
	@echo "Checking playbook syntax..."
	@mkdir -p roles
	@ln -sfn .. roles/provision-tomcat
	ANSIBLE_ROLES_PATH=./roles:../ ansible-playbook --syntax-check tests/playbook.yml -i tests/inventory

.PHONY: check
check: lint syntax
	@echo "All validation checks passed."

# ============================================================================ 
# AWS Configuration (Universal Overrides)
# ============================================================================ 
# Dynamically resolve account and region if not provided
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
AWS_REGION ?= $(shell aws configure get region 2>/dev/null)
ifeq ($(AWS_REGION),)
  AWS_REGION := us-west-2
endif
export AWS_REGION

# ============================================================================ 
# Secret Management
# ============================================================================ 
.PHONY: sync-aws
sync-aws:
	@if [ -x "../bin/sync-aws-secrets" ]; then \
		echo "Syncing AWS secrets from local session..."; \
		"../bin/sync-aws-secrets"; \
	else \
		echo "Error: ../bin/sync-aws-secrets not found or not executable."; \
		exit 1; \
	fi

.PHONY: sync-azure
sync-azure:
	@echo "Syncing Azure secrets to GitHub..."
	@gh secret set AZURE_CLIENT_ID --body "$$AZURE_CLIENT_ID"
	@gh secret set AZURE_CLIENT_SECRET --body "$$AZURE_CLIENT_SECRET"
	@gh secret set AZURE_TENANT_ID --body "$$AZURE_TENANT_ID"
	@gh secret set AZURE_SUBSCRIPTION_ID --body "$$AZURE_SUBSCRIPTION_ID"

.PHONY: sync-secrets
sync-secrets: sync-aws sync-azure
	@echo "All secrets synchronized to GitHub."

PROVIDER ?= aws
AWS_REGION ?= us-east-1

# --- Provider Dispatchers ---

.PHONY: test-provision-tomcat
test-provision-tomcat: check-credentials update-roles
	@eval $$(scripts/providers/$(PROVIDER)/discover.sh) && \
	eval $$(scripts/common/resolve-tomcat.sh) && \
	RUNNER_IP=$${LOCAL_AWS_RUNNER_IP:-$$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')} && \
	export RUNNER_IP && \
	scripts/providers/$(PROVIDER)/ingress.sh authorize && \
	trap 'scripts/providers/$(PROVIDER)/ingress.sh revoke' EXIT && \
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) test default-$(PROVIDER)-minimal-win-disk && \
	scripts/providers/$(PROVIDER)/promote-candidate.sh

.PHONY: test-upgrade-candidate
test-upgrade-candidate: check-credentials sync-$(PROVIDER) update-roles
	@eval $$(scripts/providers/$(PROVIDER)/discover.sh) && \
	eval $$(scripts/common/resolve-tomcat.sh) && \
	RUNNER_IP=$${LOCAL_AWS_RUNNER_IP:-$$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')} && \
	export RUNNER_IP && \
	scripts/providers/$(PROVIDER)/ingress.sh authorize && \
	trap 'scripts/providers/$(PROVIDER)/ingress.sh revoke' EXIT && \
	scripts/providers/$(PROVIDER)/promote-candidate.sh

# --- Provider Aliases ---

.PHONY: test-aws-provision-tomcat
test-aws-provision-tomcat:
	$(MAKE) test-provision-tomcat PROVIDER=aws

.PHONY: test-azure-provision-tomcat
test-azure-provision-tomcat:
	$(MAKE) test-provision-tomcat PROVIDER=azure

.PHONY: test-aws-upgrade-candidate
test-aws-upgrade-candidate:
	$(MAKE) test-upgrade-candidate PROVIDER=aws

.PHONY: test-aws-upgrade-candidate-latest
test-aws-upgrade-candidate-latest:
	$(MAKE) test-aws-upgrade-candidate \
		JAVA_OLD_VERSION=21 \
		JAVA_NEW_VERSION=25 \
		TOMCAT_OLD_VERSION=9.0.115 \
		TOMCAT_NEW_VERSION=9.0.120 \
		KEEP_AWS_VM=$(KEEP_AWS_VM)

# --- Legacy Compatibility / Helpers ---

.PHONY: check-credentials
check-credentials:
	@scripts/common/check-credentials.sh $(PROVIDER)

.PHONY: check-aws-credentials
check-aws-credentials:
	@scripts/common/check-credentials.sh aws

.PHONY: discover-aws-resources
discover-aws-resources:
	@scripts/providers/aws/discover.sh


# Test all suites on a platform
define TEST_ALL_SUITES
.PHONY: test-all-$(1)
test-all-$(1): update-roles destroy-$(1)
	@$(foreach s,$(SUITES),echo "=== Testing suite: $(s)-$(1) ===" && KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) test $(s)-$(1) &&) true
endef

# Test specific suite on platform
define KITCHEN_SUITE_PLATFORM_TARGETS
.PHONY: test-$(1)-$(2)
test-$(1)-$(2): update-roles destroy-$(1)-$(2)
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) test $(1)-$(2)

.PHONY: converge-$(1)-$(2)
converge-$(1)-$(2): update-roles
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge $(1)-$(2)

.PHONY: verify-$(1)-$(2)
verify-$(1)-$(2):
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify $(1)-$(2)
endef

# Platform-level targets (shortcuts for default suite)
define KITCHEN_PLATFORM_TARGETS
.PHONY: test-$(1)
test-$(1): update-roles destroy-$(1)
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) test default-$(1)

.PHONY: converge-$(1)
converge-$(1): update-roles
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge default-$(1)

.PHONY: verify-$(1)
verify-$(1):
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify default-$(1)

.PHONY: destroy-$(1)
destroy-$(1):
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy '.*-$(1)'
endef

$(foreach platform,$(PLATFORMS),$(eval $(call TEST_ALL_SUITES,$(platform))))
$(foreach platform,$(PLATFORMS),$(eval $(call KITCHEN_PLATFORM_TARGETS,$(platform))))
$(foreach platform,$(PLATFORMS),$(foreach suite,$(SUITES),$(eval $(call KITCHEN_SUITE_PLATFORM_TARGETS,$(suite),$(platform)))))

# Update test roles from parent directory
.PHONY: update-roles
update-roles:
	@echo

# Upgrade testing helpers
.PHONY: test-upgrade-win11
test-upgrade-win11: update-roles
		@echo "=== Testing Java + Tomcat upgrade on Windows 11 ==="
		@echo "Step 1: Installing Java $(JAVA_OLD_VERSION) + Tomcat $(TOMCAT_OLD_VERSION)..."
		$(load_upgrade_test_env) \
		KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) create upgrade-win11
		KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge upgrade-win11
		KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify upgrade-win11
		@echo ""
		@echo "Step 2: Upgrading to Java $(JAVA_NEW_VERSION) + Tomcat $(TOMCAT_NEW_VERSION)..."
		@sed 's/upgrade_step: 1/upgrade_step: 2/' $(KITCHEN_YAML) > .kitchen.step2.yml
		KITCHEN_YAML=.kitchen.step2.yml $(KITCHEN_CMD) converge upgrade-win11
		KITCHEN_YAML=.kitchen.step2.yml $(KITCHEN_CMD) verify upgrade-win11
		@rm -f .kitchen.step2.yml
		@echo ""
		@echo "Upgrade test complete!"


.PHONY: test-upgrade-candidate-win11
test-upgrade-candidate-win11: upgrade-cleanup-win11 update-roles
		@echo "=== Testing Java + Tomcat upgrade (candidate mode) on Windows 11 (D: drive) ==="
		@echo "Step 1: Installing Java $(JAVA_OLD_VERSION) + Tomcat $(TOMCAT_OLD_VERSION)..."
		@sed 's/.*guest: 8080, host: 8080, auto_correct: true.*/        - ["forwarded_port", {guest: 8080, host: 18080, auto_correct: true}]\n        - ["forwarded_port", {guest: 9080, host: 19080, auto_correct: true}]/' $(KITCHEN_YAML) > .kitchen.cand1.yml
		$(load_upgrade_test_env) \
		KITCHEN_YAML=.kitchen.cand1.yml $(KITCHEN_CMD) create upgrade-win11-disk
		KITCHEN_YAML=.kitchen.cand1.yml $(KITCHEN_CMD) converge upgrade-win11-disk
		KITCHEN_YAML=.kitchen.cand1.yml $(KITCHEN_CMD) verify upgrade-win11-disk || true
		@echo ""
		@echo "Step 2: Upgrading to Java $(JAVA_NEW_VERSION) + Tomcat $(TOMCAT_NEW_VERSION) with candidate workflow..."
		@sed -e 's/upgrade_step: 1/upgrade_step: 2/' \
		     -e 's/tomcat_auto_start: true/tomcat_auto_start: true\n        tomcat_candidate_enabled: true\n        tomcat_candidate_delegate: localhost\n        tomcat_candidate_delegate_port: 19080/' \
		     .kitchen.cand1.yml > .kitchen.cand2.yml
		KITCHEN_YAML=.kitchen.cand2.yml $(KITCHEN_CMD) converge upgrade-win11-disk
		KITCHEN_YAML=.kitchen.cand2.yml $(KITCHEN_CMD) verify upgrade-win11-disk
		@rm -f .kitchen.cand1.yml .kitchen.cand2.yml
		@echo ""
		@echo "Candidate upgrade test complete!"

.PHONY: upgrade-cleanup-win11
upgrade-cleanup-win11:
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy upgrade-win11-disk || true

.PHONY: test-upgrade-baseline-win11
test-upgrade-baseline-win11: update-roles
		@set -e; \
		$(load_upgrade_test_env) \
		KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) test upgrade-baseline-win11-baseline

.PHONY: candidate-cleanup-win11
candidate-cleanup-win11: upgrade-cleanup-win11
	@rm -f .kitchen.local.yml

.PHONY: test-upgrade-candidate-stack
test-upgrade-candidate-stack: test-upgrade-candidate-win11 candidate-cleanup-win11
	@echo ""
	@echo "Full candidate upgrade + cleanup complete!"

.PHONY: test-downgrade-win11
test-downgrade-win11: update-roles
	@echo "=== Testing Java + Tomcat downgrade on Windows 11 ==="
	@echo "Step 1: Installing Java $(JAVA_NEW_VERSION) + Tomcat $(TOMCAT_NEW_VERSION)..."
	@sed 's/downgrade_step: 1/downgrade_step: 1/' $(KITCHEN_YAML) > .kitchen.down1.yml
	KITCHEN_YAML=.kitchen.down1.yml $(KITCHEN_CMD) create downgrade-win11
	KITCHEN_YAML=.kitchen.down1.yml $(KITCHEN_CMD) converge downgrade-win11
	KITCHEN_YAML=.kitchen.down1.yml $(KITCHEN_CMD) verify downgrade-win11
	@echo ""
	@echo "Step 2: Downgrading to Java $(JAVA_OLD_VERSION) + Tomcat $(TOMCAT_OLD_VERSION)..."
	@sed 's/downgrade_step: 1/downgrade_step: 2/' .kitchen.down1.yml > .kitchen.down2.yml
	KITCHEN_YAML=.kitchen.down2.yml $(KITCHEN_CMD) converge downgrade-win11
	KITCHEN_YAML=.kitchen.down2.yml $(KITCHEN_CMD) verify downgrade-win11
	@rm -f .kitchen.down1.yml .kitchen.down2.yml
	@echo ""
	@echo "Downgrade test complete!"

.PHONY: downgrade-cleanup-win11
downgrade-cleanup-win11:
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy downgrade-win11

# ============================================================================ 
# Recording Tools
# ============================================================================ 
.PHONY: gif
gif:
	@command -v agg >/dev/null 2>&1 || { echo >&2 "agg is not installed. Install with: brew install agg"; exit 1; }
	@echo "Converting cast files to GIF..."
	@for cast in docs/recordings/*.cast; do \
		echo "Processing $$cast..."; \
		agg "$$cast" "$${cast%.cast}.gif"; \
		echo "Created $${cast%.cast}.gif"; \
	done
