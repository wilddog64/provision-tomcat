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

PLATFORMS := win11 win11-disk ubuntu-2404 rockylinux9 win11-azure
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
	ansible-lint .

.PHONY: syntax
syntax: deps
	@echo "Checking playbook syntax..."
	ansible-playbook --syntax-check tests/playbook.yml -i tests/inventory

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
	ansible-galaxy collection install ansible.windows chocolatey.chocolatey -p ./collections

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

.PHONY: test-azure
test-azure: update-roles
	@echo "=== Testing on Azure (win11-azure) ==="
	AZURE_ENV_FILE=scratch/azure-sandbox.env KITCHEN_YAML=.kitchen.yml $(KITCHEN_CMD) test default-win11-azure

.PHONY: test-azure-provision-tomcat
test-azure-provision-tomcat: update-roles
	@set -e; \
	env_cmd="./bin/azure-sandbox-env.sh --auto-fill --write scratch/azure-sandbox.env"; \
	echo "=== Creating Azure VM: $$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"') ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az vm create \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')" \
		--image MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest \
		--admin-username "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_ADMIN_USERNAME | cut -d'=' -f2 | tr -d '"')" \
		--admin-password "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_ADMIN_PASSWORD | cut -d'=' -f2 | tr -d '"')" \
		--location "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_LOCATION | cut -d'=' -f2 | tr -d '"')" \
		--public-ip-sku Standard \
		--data-disk-sizes-gb 20 \
		--size Standard_DS1_v2; \
	echo "=== Configuring NSG Rules ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az network nsg rule create \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--nsg-name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')NSG" \
		--name AllowWinRM --priority 1010 --destination-port-ranges 5985 --access Allow --protocol Tcp --direction Inbound; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az network nsg rule create \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--nsg-name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')NSG" \
		--name AllowTomcat --priority 1020 --destination-port-ranges 8080 9080 --access Allow --protocol Tcp --direction Inbound; \
	echo "=== Configuring WinRM Inside VM ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az vm run-command invoke \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')" \
		--command-id RunPowerShellScript --scripts 'Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $$true; Set-Item -Path "WSMan:\localhost\Service\AllowUnencrypted" -Value $$true'; \
	echo "=== Creating Local Admin Account (testadmin) ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az vm run-command invoke \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')" \
		--command-id RunPowerShellScript --scripts '$$Password = ConvertTo-SecureString "Password123!" -AsPlainText -Force; if (-not (Get-LocalUser -Name "testadmin" -ErrorAction SilentlyContinue)) { New-LocalUser "testadmin" -Password $$Password -Description "Ansible Admin"; Add-LocalGroupMember -Group "Administrators" -Member "testadmin" }'; \
	echo "=== Running Ansible Playbook ==="; \
	IP=$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az vm show \
		-d -g "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		-n "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')" \
		--query publicIps -o tsv); \
	printf "[azure]\ndefault-win11-azure ansible_host=$$IP ansible_user=testadmin ansible_password=\"Password123!\" ansible_port=5985 ansible_connection=winrm ansible_winrm_transport=basic ansible_winrm_scheme=http ansible_winrm_server_cert_validation=ignore ansible_become_method=runas ansible_become_user=azureadmin ansible_become_password=\"$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_ADMIN_PASSWORD | cut -d'=' -f2 | tr -d '"')\"\n" > scratch/azure-inventory.ini; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") rbenv exec bundle exec ansible-playbook -i scratch/azure-inventory.ini tests/playbook.yml \
		-e "env=stage2 extract_build_number=16 extract_debug=False skip_migration=true tomcat_version=9.0.113 tomcat_auto_start=true install_drive=D:" ; \
	echo "=== Azure VM Provisioning Complete! ==="; \
	if [ -z "$$KEEP_AZURE_VM" ]; then \
		echo "=== Cleaning up Azure VM and resources... ==="; \
		$(MAKE) destroy-azure-cli; \
	else \
		echo "=== KEEP_AZURE_VM is set. Skipping cleanup of Azure VM and resources. ==="; \
	fi


.PHONY: destroy-azure-cli
destroy-azure-cli:
	@set -e; \
	env_cmd="./bin/azure-sandbox-env.sh --auto-fill --write scratch/azure-sandbox.env"; \
	echo "=== Destroying Azure VM: $$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"') ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az vm delete \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')" \
		--yes --no-wait; \
	echo "=== Cleaning up Network Resources ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az network nic delete \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')VMNic" \
		--no-wait || true; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az network public-ip delete \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')PublicIP" \
		--no-wait || true; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az network nsg delete \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')NSG" \
		--no-wait || true;

.PHONY: test-upgrade-candidate-azure-cli
test-upgrade-candidate-azure-cli: update-roles
	@set -e; \
	env_cmd="./bin/azure-sandbox-env.sh --auto-fill --write scratch/azure-sandbox.env"; \
	echo "=== 1. Creating Azure VM with Data Disk: $$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"') ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az vm create \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')" \
		--image MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest \
		--admin-username "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_ADMIN_USERNAME | cut -d'=' -f2 | tr -d '"')" \
		--admin-password "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_ADMIN_PASSWORD | cut -d'=' -f2 | tr -d '"')" \
		--location "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_LOCATION | cut -d'=' -f2 | tr -d '"')" \
		--public-ip-sku Standard \
		--data-disk-sizes-gb 20 \
		--size Standard_DS1_v2; \
	echo "=== 2. Configuring Network & WinRM ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az network nsg rule create \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--nsg-name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')NSG" \
		--name AllowWinRM --priority 1010 --destination-port-ranges 5985 --access Allow --protocol Tcp --direction Inbound; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az network nsg rule create \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--nsg-name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')NSG" \
		--name AllowTomcat --priority 1020 --destination-port-ranges 8080 9080 --access Allow --protocol Tcp --direction Inbound; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az vm run-command invoke \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')" \
		--command-id RunPowerShellScript --scripts 'Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $$true; Set-Item -Path "WSMan:\localhost\Service\AllowUnencrypted" -Value $$true'; \
	echo "=== 3. Creating Local Admin Account (testadmin) ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az vm run-command invoke \
		--resource-group "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		--name "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')" \
		--command-id RunPowerShellScript --scripts '$$Password = ConvertTo-SecureString "Password123!" -AsPlainText -Force; if (-not (Get-LocalUser -Name "testadmin" -ErrorAction SilentlyContinue)) { New-LocalUser "testadmin" -Password $$Password -Description "Ansible Admin"; Add-LocalGroupMember -Group "Administrators" -Member "testadmin" }'; \
	echo "=== 4. Preparing Inventory ==="; \
	IP=$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") az vm show \
		-d -g "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"')" \
		-n "$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_VM_NAME | cut -d'=' -f2 | tr -d '"')" \
		--query publicIps -o tsv); \
	printf "[azure]\ndefault-win11-azure ansible_host=$$IP ansible_user=testadmin ansible_password=\"Password123!\" ansible_port=5985 ansible_connection=winrm ansible_winrm_transport=basic ansible_winrm_scheme=http ansible_winrm_server_cert_validation=ignore ansible_become_method=runas ansible_become_user=azureadmin ansible_become_password=\"$$($$env_cmd && cat scratch/azure-sandbox.env | grep AZURE_ADMIN_PASSWORD | cut -d'=' -f2 | tr -d '"')\"\n" > scratch/azure-inventory.ini; \
	echo "=== 5. Step 1: Installing Initial Version (Tomcat 9.0.112 / Java 17) ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") rbenv exec bundle exec ansible-playbook -i scratch/azure-inventory.ini tests/playbook-upgrade.yml \
		-e "env=stage2 upgrade_step=1 tomcat_auto_start=true install_drive=D:"; \
	echo "=== 6. Step 2: Installing Candidate Version (Tomcat 9.0.113 / Java 21) ==="; \
	$$($$env_cmd && cat scratch/azure-sandbox.env | grep "export") rbenv exec bundle exec ansible-playbook -i scratch/azure-inventory.ini tests/playbook-upgrade.yml \
		-e "env=stage2 upgrade_step=2 tomcat_auto_start=true tomcat_candidate_enabled=true tomcat_candidate_delegate_host=$$IP tomcat_candidate_delegate_port=9080 install_drive=D:"; \
	echo "=== 7. Verifying Candidate on Port 9080 ==="; \
	curl -v --connect-timeout 5 --max-time 10 http://$$IP:9080; \
	echo "=== Success! Test Complete. ==="; \
	if [ -z "$$KEEP_AZURE_VM" ]; then \
		echo "=== Cleaning up Azure VM and resources... ==="; \
		$(MAKE) destroy-azure-cli; \
	else \
		echo "=== KEEP_AZURE_VM is set. Skipping cleanup of Azure VM and resources. ==="; \
	fi


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
