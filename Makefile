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

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Available targets (auto KITCHEN_YAML=$(KITCHEN_YAML)):"
	@$(foreach p,$(PLATFORMS),echo "  test-$(p)        # kitchen test default-$(p)" &&) true
	@$(foreach p,$(PLATFORMS),echo "  converge-$(p)    # kitchen converge default-$(p)" &&) true
	@$(foreach p,$(PLATFORMS),echo "  destroy-$(p)     # kitchen destroy default-$(p)" &&) true
	@echo "Override KITCHEN_YAML=/path/to/.kitchen.yml when needed."

define KITCHEN_PLATFORM_TARGETS
.PHONY: test-$(1)
test-$(1):
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) test default-$(1)

.PHONY: converge-$(1)
converge-$(1):
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) converge default-$(1)

.PHONY: destroy-$(1)
destroy-$(1):
	KITCHEN_YAML=$(KITCHEN_YAML) $(KITCHEN_CMD) destroy default-$(1)
endef

$(foreach platform,$(PLATFORMS),$(eval $(call KITCHEN_PLATFORM_TARGETS,$(platform))))
