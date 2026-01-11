SHELL := /bin/bash
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

PLATFORMS := win11 ubuntu-2404 rockylinux9
SUITES := default latest idempotence

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Available targets (auto KITCHEN_YAML=$(KITCHEN_YAML)):"
	@echo ""
	@echo "Utility:"
	@echo "  list-kitchen-instances  # List all kitchen instances"
	@echo "  update-roles            # Update test roles from parent directory"
	@echo ""
	@echo "Quick test (default suite):"
	@$(foreach p,$(PLATFORMS),echo "  test-$(p)           # kitchen test default-$(p)" &&) true
	@echo ""
	@echo "Upgrade/Downgrade Testing:"
	@echo "  test-upgrade-win11      # Test Tomcat upgrade (9.0.112 → 9.0.113)"
	@echo "  upgrade-cleanup-win11   # Cleanup upgrade test VM"
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
	@echo "Updating test roles from parent directory..."
	@if [ -d ../provision-java ]; then \
		echo "  Syncing provision-java..."; \
		rsync -av --delete \
			--exclude='.git' \
			--exclude='.kitchen' \
			--exclude='.vagrant' \
			--exclude='.direnv' \
			--exclude='*.log' \
			../provision-java/ tests/roles/provision-java/; \
	else \
		echo "  WARNING: ../provision-java not found"; \
	fi
	@if [ -d ../windows-base ]; then \
		echo "  Syncing windows-base..."; \
		rsync -av --delete \
			--exclude='.git' \
			--exclude='.kitchen' \
			--exclude='.vagrant' \
			--exclude='.direnv' \
			--exclude='*.log' \
			../windows-base/ tests/roles/windows-base/; \
	else \
		echo "  WARNING: ../windows-base not found"; \
	fi
	@echo "✓ Test roles updated"

# Upgrade testing helpers
.PHONY: test-upgrade-win11
test-upgrade-win11: update-roles
	@echo "=== Testing Tomcat upgrade on Windows 11 ==="
	@echo "Step 1: Installing Tomcat 9.0.112..."
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) create upgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge upgrade-win11
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) verify upgrade-win11
	@echo ""
	@echo "Step 2: Upgrading to Tomcat 9.0.113..."
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
	@echo "✓ Upgrade test complete!"

.PHONY: upgrade-cleanup-win11
upgrade-cleanup-win11:
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy upgrade-win11
