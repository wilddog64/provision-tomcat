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

# Keep Ansible tooling on a consistent install path to avoid
# ansible-lint/ansible-core mismatch errors.
ANSIBLE_LINT_BIN ?= $(shell command -v ansible-lint 2>/dev/null)
BIN_DIR := $(if $(ANSIBLE_LINT_BIN),$(dir $(ANSIBLE_LINT_BIN)),)

# Helper to resolve binaries from same dir as ansible-lint or fallback to PATH
define resolve_bin
$(strip $(if $(BIN_DIR),$(if $(shell test -x $(BIN_DIR)$(1) && echo 1),$(BIN_DIR)$(1),$(shell command -v $(1) 2>/dev/null)),$(shell command -v $(1) 2>/dev/null)))
endef

ANSIBLE_BIN ?= $(call resolve_bin,ansible)
ANSIBLE_PLAYBOOK_BIN ?= $(call resolve_bin,ansible-playbook)
ANSIBLE_GALAXY_BIN ?= $(call resolve_bin,ansible-galaxy)

PLATFORMS := win11 win11-disk ubuntu-2404 rockylinux9 win11-azure
SUITES := default latest idempotence

# Version variables for upgrade/downgrade testing
JAVA_OLD_VERSION ?= 17
JAVA_NEW_VERSION ?= 21
TOMCAT_OLD_VERSION ?= 9.0.112
TOMCAT_NEW_VERSION ?= 9.0.115

# ============================================================================ 
# Azure Configuration (Universal Overrides)
# ============================================================================ 
# Dynamically resolve subscription if not provided
AZURE_SUBSCRIPTION_ID ?= $(shell az account show --query id -o tsv 2>/dev/null)
# Dynamically resolve resource group if not provided, favoring the environment variable
AZURE_RESOURCE_GROUP ?= $(shell az group list --query "[?contains(name, 'sandbox')].name" -o tsv 2>/dev/null | head -n 1)
ifeq ($(AZURE_RESOURCE_GROUP),)
  AZURE_RESOURCE_GROUP := kqvm-win11-rg
endif
AZURE_LOCATION ?= 
AZURE_IMAGE ?= MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest
AZURE_VM_SIZE ?= Standard_DS1_v2
AZURE_VM_NAME ?= kqvm-win11
AZURE_ADMIN_USERNAME ?= azureadmin
AZURE_ADMIN_PASSWORD ?= ChangeM3!SecurePassword

.DEFAULT_GOAL := help

# ============================================================================ 
# Validation Targets
# ============================================================================ 
.PHONY: lint
lint: deps
	@if [ -z "$(ANSIBLE_LINT_BIN)" ]; then echo "ERROR: ansible-lint not found in PATH"; exit 1; fi
	@echo "Running ansible-lint..."
	PATH="$(dir $(ANSIBLE_LINT_BIN)):$$PATH" $(ANSIBLE_LINT_BIN) --offline .

.PHONY: syntax
syntax: deps
	@if [ -z "$(ANSIBLE_PLAYBOOK_BIN)" ]; then echo "ERROR: ansible-playbook not found"; exit 1; fi
	@echo "Checking playbook syntax..."
	@mkdir -p roles
	@ln -sfn .. roles/provision-tomcat
	ANSIBLE_ROLES_PATH="$(ANSIBLE_ROLES_PATH)" $(ANSIBLE_PLAYBOOK_BIN) --syntax-check tests/playbook.yml -i tests/inventory

.PHONY: check
check: lint syntax
	@echo "All validation checks passed."

# ============================================================================
# Utility Targets
# ============================================================================ 

.PHONY: setup
setup:
	@./scripts/setup.sh all

.PHONY: deps
deps:
	@echo "Installing Ansible collections..."
	$(ANSIBLE_GALAXY_BIN) collection install ansible.windows community.windows chocolatey.chocolatey -p ./collections

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
	@echo "  vagrant-up              # Re-create and start Vagrant VM"
	@echo "  vagrant-login           # PowerShell into Vagrant VM"
	@echo "  vagrant-disk-setup      # Initialize and format D: drive"
	@echo "  vagrant-provision       # Provision Tomcat + Java (default playbook)"
	@echo ""
	@echo "Azure Targets (require az login):"
	@echo "  test-azure-provision-tomcat   # Standard provision test on Azure VM"
	@echo "  test-azure-upgrade-candidate # Zero-downtime candidate upgrade test"
	@echo "  test-azure-destroy           # Destroy all Azure resources created by these tests"
	@echo ""
	@echo "  Usage with Overrides:"
	@echo "    AZURE_RESOURCE_GROUP=my-rg make test-azure-provision-tomcat"
	@echo "    AZURE_IMAGE=my-image-urn make test-azure-provision-tomcat"
	@echo ""
	@echo "Quick test (default suite):"
	@$(foreach p,$(PLATFORMS),echo "  test-$(p)           # kitchen test default-$(p)" &&) true
	@echo ""
	@echo "Override KITCHEN_YAML=/path/to/.kitchen.yml when needed."

# Build extra vars for Ansible
EXTRA_VARS := $(if $(ADO_PAT_TOKEN),ado_pat_token=$(ADO_PAT_TOKEN),)

.PHONY: test-azure-provision-tomcat
test-azure-provision-tomcat: update-roles
	@set -e; \
	echo "=== Detecting Azure Environment ==="; \
	SUB=$(AZURE_SUBSCRIPTION_ID); \
	RG=$(AZURE_RESOURCE_GROUP); \
	echo "Using Subscription: $$SUB"; \
	echo "Using Resource Group: $$RG"; \
	LOC=$(AZURE_LOCATION); \
	if [ -z "$$LOC" ]; then LOC=$$(az group show --name "$$RG" --query location -o tsv); fi; \
	echo "Using Location: $$LOC"; \
	MY_IP=$$(curl -s https://api.ipify.org); \
	NAME=$(AZURE_VM_NAME); \
	USER=$(AZURE_ADMIN_USERNAME); \
	PASS="$(AZURE_ADMIN_PASSWORD)"; \
	IMAGE="$(AZURE_IMAGE)"; \
	SIZE="$(AZURE_VM_SIZE)"; \
	echo "=== Creating Azure VM: $$NAME in $$RG ($$LOC) ==="; \
	az vm create --subscription "$$SUB" --resource-group "$$RG" --name "$$NAME" \
		--image "$$IMAGE" --admin-username "$$USER" --admin-password "$$PASS" --location "$$LOC" \
		--public-ip-sku Standard --data-disk-sizes-gb 20 --size "$$SIZE"; \
	echo "=== Configuring NSG Rules (Source IP: $$MY_IP) ==="; \
	az network nsg rule create --subscription "$$SUB" --resource-group "$$RG" --nsg-name "$${NAME}NSG" --name AllowWinRM --priority 1010 --destination-port-ranges 5985 --access Allow --protocol Tcp --direction Inbound --source-address-prefixes "$$MY_IP"; \
	az network nsg rule create --subscription "$$SUB" --resource-group "$$RG" --nsg-name "$${NAME}NSG" --name AllowTomcat --priority 1020 --destination-port-ranges 8080 9080 --access Allow --protocol Tcp --direction Inbound --source-address-prefixes "$$MY_IP"; \
	echo "=== Configuring WinRM Inside VM ==="; \
	az vm run-command invoke --subscription "$$SUB" --resource-group "$$RG" --name "$$NAME" --command-id RunPowerShellScript --scripts 'winrm quickconfig -q; Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $$true; Set-Item -Path "WSMan:\localhost\Service\AllowUnencrypted" -Value $$true; New-NetFirewallRule -DisplayName "Allow WinRM HTTP" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow'; \
	echo "=== Creating Local Admin Account (testadmin) ==="; \
	az vm run-command invoke --subscription "$$SUB" --resource-group "$$RG" --name "$$NAME" --command-id RunPowerShellScript --scripts \
		'$$Password = ConvertTo-SecureString "Password123!" -AsPlainText -Force; if (-not (Get-LocalUser -Name "testadmin" -ErrorAction SilentlyContinue)) { New-LocalUser "testadmin" -Password $$Password -Description "Ansible Admin"; Add-LocalGroupMember -Group "Administrators" -Member "testadmin" };'; \
	IP=$$(az vm show --subscription "$$SUB" -d -g "$$RG" -n "$$NAME" --query publicIps -o tsv); \
	echo "=== Waiting for WinRM on $$IP:5985... ==="; \
	for i in {1..60}; do if nc -z -w 5 $$IP 5985; then break; fi; echo "Waiting... ($$i/60)"; sleep 10; if [ $$i -eq 60 ]; then echo "Timeout waiting for WinRM"; exit 1; fi; done; \
	sleep 10; \
	mkdir -p scratch; \
	printf "[azure]\ndefault-win11-azure ansible_host=$$IP ansible_user=testadmin ansible_password=\"Password123!\" ansible_port=5985 ansible_connection=winrm ansible_winrm_transport=basic ansible_winrm_scheme=http ansible_winrm_server_cert_validation=ignore ansible_winrm_read_timeout_sec=300 ansible_become_method=runas ansible_become_user=$$USER ansible_become_password=\"$$PASS\"\n" > scratch/azure-inventory.ini; \
	echo "=== Verifying Ansible Connectivity (win_ping) ==="; \
	ansible -i scratch/azure-inventory.ini -m win_ping all; \
	echo "=== Running Integration Test ==="; \
	ansible-playbook -i scratch/azure-inventory.ini tests/playbook.yml \
		-e "env=stage2 extract_build_number=16 extract_debug=False skip_migration=true tomcat_version=9.0.115 tomcat_auto_start=true install_drive=D:" ; \
	echo "=== Verifying Tomcat Connectivity from Controller ==="; \
	for i in {1..12}; do \
		if curl -s --connect-timeout 5 --max-time 10 "http://$$IP:8080" > /dev/null; then \
			echo "SUCCESS: Tomcat is reachable at http://$$IP:8080"; \
			break; \
		fi; \
		echo "Waiting for Tomcat to respond... ($$i/12)"; \
		sleep 10; \
		if [ $$i -eq 12 ]; then echo "FAILED: Tomcat is not reachable externally"; exit 1; fi; \
	done; \
	echo "=== Azure VM Provisioning Complete! ==="; \
	if [ -z "$$KEEP_AZURE_VM" ]; then echo "=== Cleaning up... ==="; $(MAKE) test-azure-destroy; else echo "=== KEEP_AZURE_VM is set. Skipping cleanup. ==="; fi

.PHONY: test-azure-destroy
test-azure-destroy:
	@set -e; \
	echo "=== Detecting Azure Environment for Cleanup ==="; \
	SUB=$(AZURE_SUBSCRIPTION_ID); \
	if [ -z "$$SUB" ]; then SUB=$$(az account show --query id -o tsv); fi; \
	RG=$(AZURE_RESOURCE_GROUP); \
	if [ -z "$$RG" ]; then RG=$$(az group list --query "[?contains(name, 'playground-sandbox')].name" -o tsv | head -n 1); fi; \
	NAME=$(AZURE_VM_NAME); \
	echo "=== Destroying Azure VM: $$NAME in $$RG ==="; \
	az vm delete --subscription "$$SUB" --resource-group "$$RG" --name "$$NAME" --yes; \
	echo "=== Cleaning up Network Resources ==="; \
	az network nic delete --subscription "$$SUB" --resource-group "$$RG" --name "$${NAME}VMNic" || true; \
	az network public-ip delete --subscription "$$SUB" --resource-group "$$RG" --name "$${NAME}PublicIP" || true; \
	az network nsg delete --subscription "$$SUB" --resource-group "$$RG" --name "$${NAME}NSG" || true;

.PHONY: test-azure-upgrade-candidate
test-azure-upgrade-candidate: update-roles
	@set -e; \
	echo "=== Detecting Azure Environment ==="; \
	SUB=$(AZURE_SUBSCRIPTION_ID); \
	RG=$(AZURE_RESOURCE_GROUP); \
	echo "Using Subscription: $$SUB"; \
	echo "Using Resource Group: $$RG"; \
	LOC=$(AZURE_LOCATION); \
	if [ -z "$$LOC" ]; then LOC=$$(az group show --name "$$RG" --query location -o tsv); fi; \
	echo "Using Location: $$LOC"; \
	MY_IP=$$(curl -s https://api.ipify.org); \
	NAME=$(AZURE_VM_NAME); \
	USER=$(AZURE_ADMIN_USERNAME); \
	PASS="$(AZURE_ADMIN_PASSWORD)"; \
	IMAGE="$(AZURE_IMAGE)"; \
	SIZE="$(AZURE_VM_SIZE)"; \
	echo "=== 1. Creating Azure VM: $$NAME ==="; \
	az vm create --subscription "$$SUB" --resource-group "$$RG" --name "$$NAME" \
		--image "$$IMAGE" --admin-username "$$USER" --admin-password "$$PASS" --location "$$LOC" \
		--public-ip-sku Standard --data-disk-sizes-gb 20 --size "$$SIZE"; \
	echo "=== 2. Configuring NSG Rules (Source IP: $$MY_IP) ==="; \
	az network nsg rule create --subscription "$$SUB" --resource-group "$$RG" --nsg-name "$${NAME}NSG" --name AllowWinRM --priority 1010 --destination-port-ranges 5985 --access Allow --protocol Tcp --direction Inbound --source-address-prefixes "$$MY_IP"; \
	az network nsg rule create --subscription "$$SUB" --resource-group "$$RG" --nsg-name "$${NAME}NSG" --name AllowTomcat --priority 1020 --destination-port-ranges 8080 9080 --access Allow --protocol Tcp --direction Inbound --source-address-prefixes "$$MY_IP"; \
	echo "=== 3. Configuring WinRM & Local Admin ==="; \
	az vm run-command invoke --subscription "$$SUB" --resource-group "$$RG" --name "$$NAME" --command-id RunPowerShellScript --scripts 'winrm quickconfig -q; Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $$true; Set-Item -Path "WSMan:\localhost\Service\AllowUnencrypted" -Value $$true; New-NetFirewallRule -DisplayName "Allow WinRM HTTP" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow'; \
	az vm run-command invoke --subscription "$$SUB" --resource-group "$$RG" --name "$$NAME" --command-id RunPowerShellScript --scripts \
		'$$Password = ConvertTo-SecureString "Password123!" -AsPlainText -Force; if (-not (Get-LocalUser -Name "testadmin" -ErrorAction SilentlyContinue)) { New-LocalUser "testadmin" -Password $$Password -Description "Ansible Admin"; Add-LocalGroupMember -Group "Administrators" -Member "testadmin" };'; \
	IP=$$(az vm show --subscription "$$SUB" -d -g "$$RG" -n "$$NAME" --query publicIps -o tsv); \
	echo "=== Waiting for WinRM on $$IP:5985... ==="; \
	for i in {1..60}; do if nc -z -w 5 $$IP 5985; then break; fi; echo "Waiting... ($$i/60)"; sleep 10; if [ $$i -eq 60 ]; then echo "Timeout waiting for WinRM"; exit 1; fi; done; \
	sleep 10; \
	mkdir -p scratch; \
	printf "[azure]\ndefault-win11-azure ansible_host=$$IP ansible_user=testadmin ansible_password=\"Password123!\" ansible_port=5985 ansible_connection=winrm ansible_winrm_transport=basic ansible_winrm_scheme=http ansible_winrm_server_cert_validation=ignore ansible_winrm_read_timeout_sec=300 ansible_become_method=runas ansible_become_user=$$USER ansible_become_password=\"$$PASS\"\n" > scratch/azure-inventory.ini; \
	echo "=== 5. Step 1: Installing Initial Version ==="; \
	ansible-playbook -i scratch/azure-inventory.ini tests/playbook-upgrade.yml -e "env=stage2 upgrade_step=1 tomcat_auto_start=true install_drive=D:"; \
	echo "=== 6. Step 2: Installing Candidate Version ==="; \
	ansible-playbook -i scratch/azure-inventory.ini tests/playbook-upgrade.yml -e "env=stage2 upgrade_step=2 tomcat_auto_start=true tomcat_candidate_enabled=true tomcat_candidate_delegate_host=$$IP tomcat_candidate_delegate_port=9080 install_drive=D:"; \
	echo "=== 7. Verifying Candidate on Port 9080 ==="; \
	curl -v --connect-timeout 5 --max-time 10 http://$$IP:9080; \
	echo "=== Success! Test Complete. ==="; \
	if [ -z "$$KEEP_AZURE_VM" ]; then echo "=== Cleaning up... ==="; $(MAKE) test-azure-destroy; else echo "=== Keeping VM... ==="; fi

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
		"        - [\'forwarded_port\', {guest: 8080, host: 18080, auto_correct: true}]" \
		"        - [\'forwarded_port\', {guest: 9080, host: 19080, auto_correct: true}]" \
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
		"        - [\'forwarded_port\', {guest: 8080, host: 18080, auto_correct: true}]" \
		"        - [\'forwarded_port\', {guest: 9080, host: 19080, auto_correct: true}]" \
		'    provisioner:' \
		'      playbook: tests/playbook-upgrade.yml' \
		'      extra_vars:' \
		'        upgrade_step: 2' \
		'        tomcat_auto_start: true' \
		'        tomcat_candidate_enabled: true' \
		'        tomcat_candidate_delegate: localhost' \
		'        tomcat_candidate_delegate_port: 19080' \
		'    verifier:' \
		'      name: shell' \
		'      command: |' \
		'        echo "=== Verifying Tomcat from controller (localhost:18080) ===" ' \
		'        for attempt in 1 2 3 4 5 6 7 8 9 10; do' \
		'          echo "" ' \
		'          echo "--- Attempt $${attempt}/10 ---" ' \
		'          echo "curl -v --connect-timeout 5 --max-time 10 http://localhost:18080" ' \
		'          if curl -v --connect-timeout 5 --max-time 10 http://localhost:18080 2>&1; then' \
		'            echo "" ' \
		'            echo "SUCCESS: Tomcat responded on port 18080" ' \
		'            exit 0' \
		'          fi' \
		'          echo "  Waiting 10 seconds before retry..." ' \
		'          sleep 10' \
		'        done' \
		'        echo "" ' \
		'        echo "FAILED: Tomcat did not respond on port 18080 after 10 attempts" >&2' \
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
