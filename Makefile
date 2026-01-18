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
  KITCHEN_CMD ?= rbenv exec kitchen
else
  KITCHEN_CMD ?= kitchen
endif

PLATFORMS := win11 win11-disk ubuntu-2404 rockylinux9
SUITES := default latest idempotence

# Version variables for upgrade/downgrade testing
JAVA_OLD_VERSION ?= 17
JAVA_NEW_VERSION ?= 21
TOMCAT_OLD_VERSION ?= 9.0.112
TOMCAT_NEW_VERSION ?= 9.0.113

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Available targets (auto KITCHEN_YAML=$(KITCHEN_YAML)):"
	@echo ""
	@echo "Utility:"
	@echo "  list-kitchen-instances  # List all kitchen instances"
	@echo "  update-roles            # Update test roles from parent directory"
	@echo "  vagrant-up              # Bring up Vagrant VM (default: stromweld/windows-11)"
	@echo "  vagrant-up-disk         # Bring up VM with windows11-disk box (D: drive)"
	@echo "  vagrant-up-baseline     # Bring up VM with windows11-tomcat112 box"
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

.PHONY: list-kitchen-instances
list-kitchen-instances:
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) list

.PHONY: vagrant-up
vagrant-up: vbox-cleanup-disks
	vagrant up

.PHONY: vagrant-up-disk
vagrant-up-disk:
	VAGRANT_BOX=windows11-disk vagrant up

.PHONY: vagrant-up-baseline
vagrant-up-baseline:
	VAGRANT_BOX=windows11-tomcat112 vagrant up

.PHONY: vagrant-update-baseline
vagrant-update-baseline:
	./bin/vagrant-update-baseline.sh

.PHONY: vagrant-upgrade-demo
vagrant-upgrade-demo:
	./bin/vagrant-upgrade-demo.sh $(if $(KEEP),--keep,)

.PHONY: vagrant-destroy
vagrant-destroy:
	vagrant destroy -f

.PHONY: vagrant-destroy-upgrade
vagrant-destroy-upgrade:
	VAGRANT_VAGRANTFILE=Vagrantfile-upgrade vagrant destroy -f

.PHONY: vbox-cleanup-disks
vbox-cleanup-disks:
	./bin/vbox-cleanup-disks.sh

.PHONY: vagrant-disk-setup
vagrant-disk-setup:
	vagrant provision --provision-with disk_setup

.PHONY: vagrant-provision
vagrant-provision:
	vagrant provision --provision-with ansible

.PHONY: vagrant-provision-step1
vagrant-provision-step1:
	vagrant provision --provision-with ansible_upgrade_step1

.PHONY: vagrant-provision-step2
vagrant-provision-step2:
	vagrant provision --provision-with ansible_upgrade_step2

.PHONY: vagrant-build-baseline
vagrant-build-baseline: vbox-cleanup-disks
	./bin/vagrant-build-baseline.sh

.PHONY: vagrant-build-baseline-minimal
vagrant-build-baseline-minimal: vbox-cleanup-disks
	./bin/vagrant-build-baseline.sh --disk-only

# Test all suites on a platform
define TEST_ALL_SUITES
.PHONY: test-all-$(1)
test-all-$(1): update-roles
	@$(foreach s,$(SUITES),echo "=== Testing suite: $(s)-$(1) ===" && KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) test $(s)-$(1) &&) true
endef

# Test specific suite on platform
define KITCHEN_SUITE_PLATFORM_TARGETS
.PHONY: test-$(1)-$(2)
test-$(1)-$(2): update-roles
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
test-$(1): update-roles
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
	@rm -f .kitchen.local.yml
	@echo "=== Testing Java + Tomcat upgrade on Windows 11 ==="
	@echo "Step 1: Installing Java 17 + Tomcat 9.0.112..."
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) create upgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge upgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify upgrade-win11
	@echo ""
	@echo "Step 2: Upgrading to Java 21 + Tomcat 9.0.113..."
	@echo "Updating .kitchen.local.yml for step 2..."
	@echo "---" > .kitchen.local.yml
	@echo "suites:" >> .kitchen.local.yml
	@echo "  - name: upgrade" >> .kitchen.local.yml
	@echo "    provisioner:" >> .kitchen.local.yml
	@echo "      playbook: tests/playbook-upgrade.yml" >> .kitchen.local.yml
	@echo "      extra_vars:" >> .kitchen.local.yml
	@echo "        upgrade_step: 2" >> .kitchen.local.yml
	@echo "        tomcat_auto_start: true" >> .kitchen.local.yml
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge upgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify upgrade-win11
	@rm -f .kitchen.local.yml
	@echo ""
	@echo "Upgrade test complete!"



.PHONY: test-upgrade-candidate-win11
test-upgrade-candidate-win11: upgrade-cleanup-win11 update-roles
	@rm -f .kitchen.local.yml
	@echo "Preparing .kitchen.local.yml with candidate port forwarding..."
	@printf '%s\n' \
		'---' \
		'suites:' \
		'  - name: upgrade' \
		'    driver:' \
		"      network:" \
		"        - ['forwarded_port', {guest: 8080, host: 8080, auto_correct: true}]" \
		"        - ['forwarded_port', {guest: 9080, host: 9080, auto_correct: true}]" \
	> .kitchen.local.yml
	@echo
	@echo "=== Testing Java + Tomcat upgrade (candidate mode) on Windows 11 (D: drive) ==="
	@echo "Step 1: Installing Java 17 + Tomcat 9.0.112..."
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) create upgrade-win11-disk
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge upgrade-win11-disk
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify upgrade-win11-disk || true
	@echo ""
	@echo "Step 2: Upgrading to Java 21 + Tomcat 9.0.113 with candidate workflow..."
	@echo "Updating .kitchen.local.yml for candidate testing..."
	@printf '%s\n' \
		'---' \
		'suites:' \
		'  - name: upgrade' \
		'    driver:' \
		"      network:" \
		"        - ['forwarded_port', {guest: 8080, host: 8080, auto_correct: true}]" \
		"        - ['forwarded_port', {guest: 9080, host: 9080, auto_correct: true}]" \
		'    provisioner:' \
		'      playbook: tests/playbook-upgrade.yml' \
		'      extra_vars:' \
		'        upgrade_step: 2' \
		'        tomcat_auto_start: true' \
		'        tomcat_candidate_enabled: true' \
		'        tomcat_candidate_delegate: localhost' \
		'    verifier:' \
		'      name: shell' \
		'      command: |' \
		'        echo "Waiting for Tomcat to respond on port 8080..."' \
		'        for attempt in {1..10}; do' \
		'          if curl --connect-timeout 5 --max-time 10 -f http://localhost:8080 >/dev/null 2>&1; then' \
		'            exit 0' \
		'          fi' \
		'          if curl --connect-timeout 5 --max-time 10 http://localhost:8080 | grep -q "404"; then' \
		'            exit 0' \
		'          fi' \
		'          echo "  attempt $${attempt}/10: still waiting..."' \
		'          sleep 10' \
		'        done' \
		'        echo "Tomcat failed to respond on port 8080" >&2' \
		'        exit 1' \
		> .kitchen.local.yml
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge upgrade-win11-disk
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify upgrade-win11-disk
	@rm -f .kitchen.local.yml
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
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) create downgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge downgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify downgrade-win11
	@echo ""
	@echo "Step 2: Downgrading to Java $(JAVA_OLD_VERSION) + Tomcat $(TOMCAT_OLD_VERSION)..."
	@echo "Updating .kitchen.local.yml for step 2..."
	@echo "---" > .kitchen.local.yml
	@echo "suites:" >> .kitchen.local.yml
	@echo "  - name: downgrade" >> .kitchen.local.yml
	@echo "    provisioner:" >> .kitchen.local.yml
	@echo "      playbook: tests/playbook-downgrade.yml" >> .kitchen.local.yml
	@echo "      extra_vars:" >> .kitchen.local.yml
	@echo "        downgrade_step: 2" >> .kitchen.local.yml
	@echo "        tomcat_auto_start: true" >> .kitchen.local.yml
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge downgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify downgrade-win11
	@rm -f .kitchen.local.yml
	@echo ""
	@echo "Downgrade test complete!"

.PHONY: downgrade-cleanup-win11
downgrade-cleanup-win11:
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy downgrade-win11
