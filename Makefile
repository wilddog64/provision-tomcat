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
  AWS_REGION := us-east-1
endif

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

.PHONY: test-aws-provision-tomcat
test-aws-provision-tomcat: update-roles
	@set -e; \
	echo "=== Detecting AWS Environment ==="; \
	ACC=$(AWS_ACCOUNT_ID); \
	REG=$(AWS_REGION); \
	echo "Using Account: $$ACC"; \
	echo "Using Region: $$REG"; \
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy default-aws-minimal-win-disk; \
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) create default-aws-minimal-win-disk; \
	IP=$$(yq .hostname .kitchen/default-aws-minimal-win-disk.yml); \
	echo "=== Waiting for WinRM on $$IP:5985... ==="; \
	for i in {1..60}; do if nc -z -w 5 $$IP 5985; then break; fi; echo "Waiting... ($$i/60)"; sleep 10; if [ $$i -eq 60 ]; then echo "Timeout waiting for WinRM"; exit 1; fi; done; \
	sleep 10; \
	echo "=== Running Integration Test ==="; \
	KITCHEN_YAML=$(KITCHEN_YAML) ANSIBLE_HOST_OVERRIDE=$$IP $(KITCHEN_CMD) converge default-aws-minimal-win-disk; \
	echo "=== Verifying Ansible Connectivity (win_ping) ==="; \
	ANSIBLE_CONFIG=ansible.cfg ANSIBLE_HOST_OVERRIDE=$$IP ansible -i .kitchen/ansible_inventory/ansible_inventory.ini -m win_ping all; \
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify default-aws-minimal-win-disk; \
	if [ -z "$$KEEP_AWS_VM" ]; then echo "=== Cleaning up... ==="; KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy default-aws-minimal-win-disk; else echo "=== KEEP_AWS_VM is set. Skipping cleanup. ==="; fi

.PHONY: test-aws-upgrade-candidate
test-aws-upgrade-candidate: update-roles
	@set -e; \
	echo "=== Detecting AWS Environment ==="; \
	ACC=$(AWS_ACCOUNT_ID); \
	REG=$(AWS_REGION); \
	echo "Using Account: $$ACC"; \
	echo "Using Region: $$REG"; \
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy upgrade-candidate-aws-disk-aws-minimal-win-disk; \
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) create upgrade-candidate-aws-disk-aws-minimal-win-disk; \
	IP=$$(yq .hostname .kitchen/upgrade-candidate-aws-disk-aws-minimal-win-disk.yml); \
	echo "=== Waiting for WinRM on $$IP:5985... ==="; \
	for i in {1..60}; do if nc -z -w 5 $$IP 5985; then break; fi; echo "Waiting... ($$i/60)"; sleep 10; if [ $$i -eq 60 ]; then echo "Timeout waiting for WinRM"; exit 1; fi; done; \
	sleep 10; \
	echo "=== Running Candidate Upgrade Test ==="; \
	KITCHEN_YAML=$(KITCHEN_YAML) ANSIBLE_HOST_OVERRIDE=$$IP $(KITCHEN_CMD) converge upgrade-candidate-aws-disk-aws-minimal-win-disk; \
	echo "=== Verifying Ansible Connectivity (win_ping) ==="; \
	ANSIBLE_CONFIG=ansible.cfg ANSIBLE_HOST_OVERRIDE=$$IP ansible -i .kitchen/ansible_inventory/ansible_inventory.ini -m win_ping all; \
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify upgrade-candidate-aws-disk-aws-minimal-win-disk; \
	if [ -z "$$KEEP_AWS_VM" ]; then echo "=== Cleaning up... ==="; KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy upgrade-candidate-aws-disk-aws-minimal-win-disk; else echo "=== KEEP_AWS_VM is set. Skipping cleanup. ==="; fi

# ============================================================================
# Utility Targets
# ============================================================================ 

.PHONY: setup

setup:

	@./scripts/setup.sh all



.PHONY: deps
deps:
	@echo "Installing Ruby dependencies..."
	@rbenv exec bundle install || bundle install
	@echo "Installing Ansible collections..."
	ansible-galaxy collection install -r requirements.yml -p ./collections

# ============================================================================ 
# Help
# ============================================================================ 
.PHONY: help
help:
	@echo "Available targets (auto KITCHEN_YAML=$(KITCHEN_YAML)):".
	@echo ""
	@echo "Validation:"
	@echo "  lint                # Run ansible-lint"
	@echo "  syntax              # Check playbook syntax"
	@echo "  check               # Run all validation checks"
	@echo "  deps                # Install Ansible collections to ./collections"
	@echo ""
	@echo "Utility:"
	@echo "  list-kitchen-instances  # List all kitchen instances"
	@echo "  update-roles            # Update test roles from parent directory"
	@echo "  vagrant-up              # Re-create and start Vagrant VM (default: stromweld/windows-11)"
	@echo "  vagrant-up-disk         # Bring up VM with windows11-disk box (D: drive)"
	@echo "  vagrant-up-baseline     # Bring up VM with windows11-tomcat112 box"
	@echo "  vagrant-login           # PowerShell into Vagrant VM"
	@echo "  vagrant-ssh             # Alias for vagrant-login"
	@echo "  vagrant-disk-setup      # Initialize and format D: drive"
	@echo "  vagrant-provision       # Provision Tomcat + Java (default playbook)"
	@echo "  vagrant-provision-step1 # Provision older Tomcat 9.0.112 + Java 17"
	@echo "  vagrant-provision-step2 # Provision newer Tomcat 9.0.113 + Java 21"
	@echo "  vagrant-build-baseline  # Build baseline box with D: drive + Tomcat + Java"
	@echo "  vagrant-build-baseline-minimal # Build minimal box with D: drive only"
	@echo "  vagrant-update-baseline # Rebuild baseline Win11 + Tomcat 9.0.112 box"
	@echo "  vagrant-upgrade-demo    # Run upgrade-only demo via Vagrantfile-upgrade (append KEEP to skip destroy)"
	@echo "  vagrant-destroy         # Destroy current Vagrant VM (default Vagrantfile)"
	@echo "  vagrant-destroy-upgrade # Destroy VM defined by Vagrantfile-upgrade"
	@echo "  vbox-cleanup-disks      # Clean up stale VirtualBox disk registrations"
	@echo "  fix-vbox-locks          # Fix locked/stuck VirtualBox VMs"
	@echo ""
	@echo "Quick test (default suite):"
	@$(foreach p,$(PLATFORMS),echo "  test-$(p)           # kitchen test default-$(p)" &&) true
	@echo ""
	@echo "Upgrade/Downgrade Testing:"
	@echo "  test-upgrade-win11      # Test Java (17→21) + Tomcat (9.0.112→9.0.113) upgrade"
	@echo "  test-upgrade-candidate-win11 # Same as above but exercises candidate workflow"
	@echo "  test-upgrade-baseline-win11 # Run upgrade step 2 on baseline box (candidate workflow only)"
	@echo "  candidate-cleanup-win11    # Remove candidate config + destroy upgrade VM"
	@echo "  upgrade-cleanup-win11   # Cleanup upgrade test VM"
	@echo "  test-downgrade-win11    # Test Java (21→17) + Tomcat (9.0.113→9.0.112) downgrade"
	@echo "  downgrade-cleanup-win11 # Cleanup downgrade test VM"
	@echo "  test-upgrade-candidate-stack # Run normal upgrade + candidate workflow + cleanup"
	@echo ""
	@echo "Test specific suite on platform:"
	@$(foreach p,$(PLATFORMS),$(foreach s,$(SUITES),echo "  test-$(s)-$(p)     # kitchen test $(s)-$(p)" &&)) true
	@echo ""
	@echo "Test all suites on a platform:"
	@$(foreach p,$(PLATFORMS),echo "  test-all-$(p)       # Run all test suites on $(p)" &&) true
	@echo ""
	@echo "Converge/Verify/Destroy (default suite):"
	@$(foreach p,$(PLATFORMS),echo "  converge-$(p)       # kitchen converge default-$(p)" &&) true
	@$(foreach p,$(PLATFORMS),echo "  verify-$(p)         # kitchen verify default-$(p)" &&) true
	@$(foreach p,$(PLATFORMS),echo "  destroy-$(p)        # kitchen destroy all $(p) instances" &&) true
	@echo ""
	@echo "Override KITCHEN_YAML=/path/to/.kitchen.yml when needed."
	@echo "See TESTING-UPGRADES.md for detailed upgrade testing documentation."

# Build extra vars for Ansible
EXTRA_VARS := $(if $(ADO_PAT_TOKEN),ado_pat_token=$(ADO_PAT_TOKEN),)

.PHONY: list-kitchen-instances
list-kitchen-instances:
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) list

.PHONY: vagrant-up
vagrant-up: vagrant-destroy vbox-cleanup-disks
	vagrant up

.PHONY: vagrant-login
vagrant-login:
	vagrant powershell

.PHONY: vagrant-ssh
vagrant-ssh: vagrant-login

.PHONY: vagrant-up-disk
vagrant-up-disk:
	VAGRANT_BOX=windows11-disk vagrant up

.PHONY: vagrant-up-baseline
vagrant-up-baseline:
	VAGRANT_BOX=windows11-tomcat112 vagrant up

.PHONY: vagrant-update-baseline
vagrant-update-baseline:
	./bin/vagrant-update-baseline

.PHONY: vagrant-upgrade-demo
vagrant-upgrade-demo:
	./bin/vagrant-upgrade-demo $(if $(KEEP),--keep,)

.PHONY: vagrant-destroy
vagrant-destroy:
	vagrant destroy -f

.PHONY: vagrant-destroy-upgrade
vagrant-destroy-upgrade:
	VAGRANT_VAGRANTFILE=Vagrantfile-upgrade vagrant destroy -f

.PHONY: vbox-cleanup-disks
vbox-cleanup-disks:
	./bin/vbox-cleanup-disks

.PHONY: fix-vbox-locks
fix-vbox-locks:
	@echo "Checking for locked VirtualBox VMs..."
	@pids=$$(ps aux | grep VBoxHeadless | grep "provision-tomcat" | grep -v grep | awk '{print $$2}'); \
	if [ -n "$$pids" ]; then \
		echo "Found hung VBoxHeadless process(es): $$pids"; \
		echo "Killing..."; \
		kill -9 $$pids; \
	else \
		echo "No hung VBox processes found."; \
	fi
	@echo "Cleaning up stuck VMs..."
	@vms=$$(VBoxManage list vms | grep "provision-tomcat" | grep -o '{\(.*\)}' | tr -d '{}'); \
	for uuid in $$vms; do \
		echo "Checking VM: $$uuid"; \
		state=$$(VBoxManage showvminfo $$uuid --machinereadable | grep '^VMState=' | cut -d'"' -f2); \
		if [ "$$state" = "aborted" ] || [ "$$state" = "stopping" ]; then \
			echo "  VM in bad state ($$state). Unregistering..."; \
			VBoxManage unregistervm $$uuid --delete || true; \
		fi; \
	done
	@echo "Done."

.PHONY: vagrant-disk-setup
vagrant-disk-setup:
	$(if $(EXTRA_VARS),ansible_extra_vars="$(EXTRA_VARS)" ,)vagrant provision --provision-with disk_setup

.PHONY: vagrant-provision
vagrant-provision:
	$(if $(EXTRA_VARS),ansible_extra_vars="$(EXTRA_VARS)" ,)vagrant provision --provision-with ansible

.PHONY: vagrant-provision-step1
vagrant-provision-step1:
	$(if $(EXTRA_VARS),ansible_extra_vars="$(EXTRA_VARS)" ,)vagrant provision --provision-with ansible_upgrade_step1

.PHONY: vagrant-provision-step2
vagrant-provision-step2:
	$(if $(EXTRA_VARS),ansible_extra_vars="$(EXTRA_VARS)" ,)vagrant provision --provision-with ansible_upgrade_step2

.PHONY: vagrant-build-baseline
vagrant-build-baseline: vbox-cleanup-disks
	./bin/vagrant-build-baseline

.PHONY: vagrant-build-baseline-minimal
vagrant-build-baseline-minimal: vbox-cleanup-disks
	./bin/vagrant-build-baseline --disk-only

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
	@echo "Step 1: Installing Java 17 + Tomcat 9.0.112..."
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) create upgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge upgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify upgrade-win11
	@echo ""
	@echo "Step 2: Upgrading to Java 21 + Tomcat 9.0.113..."
	@sed 's/upgrade_step: 1/upgrade_step: 2/' $(KITCHEN_YAML) > .kitchen.step2.yml
	KITCHEN_YAML=.kitchen.step2.yml $(KITCHEN_CMD) converge upgrade-win11
	KITCHEN_YAML=.kitchen.step2.yml $(KITCHEN_CMD) verify upgrade-win11
	@rm -f .kitchen.step2.yml
	@echo ""
	@echo "Upgrade test complete!"


.PHONY: test-upgrade-candidate-win11
test-upgrade-candidate-win11: upgrade-cleanup-win11 update-roles
	@echo "=== Testing Java + Tomcat upgrade (candidate mode) on Windows 11 (D: drive) ==="
	@echo "Step 1: Installing Java 17 + Tomcat 9.0.112..."
	@sed 's/auto_correct: true/auto_correct: true\n    network:\n        - ["forwarded_port", {guest: 8080, host: 18080, auto_correct: true}]\n        - ["forwarded_port", {guest: 9080, host: 19080, auto_correct: true}]/' $(KITCHEN_YAML) > .kitchen.cand1.yml
	KITCHEN_YAML=.kitchen.cand1.yml $(KITCHEN_CMD) create upgrade-win11-disk
	KITCHEN_YAML=.kitchen.cand1.yml $(KITCHEN_CMD) converge upgrade-win11-disk
	KITCHEN_YAML=.kitchen.cand1.yml $(KITCHEN_CMD) verify upgrade-win11-disk || true
	@echo ""
	@echo "Step 2: Upgrading to Java 21 + Tomcat 9.0.113 with candidate workflow..."
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
