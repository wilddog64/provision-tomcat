# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  # Use VAGRANT_BOX env var to switch boxes:
  #   VAGRANT_BOX=windows11-disk vagrant up    # Minimal box with D: drive
  #   VAGRANT_BOX=windows11-tomcat112 vagrant up  # Full baseline box
  config.vm.box = ENV.fetch('VAGRANT_BOX', 'stromweld/windows-11')

  config.vm.communicator = "winrm"
  config.winrm.username = "vagrant"
  config.winrm.password = "vagrant"
  config.winrm.transport = :plaintext
  config.winrm.basic_auth_only = true

  # Add secondary disk for D: drive (default 50GB, override with VAGRANT_DISK_SIZE_GB)
  disk_size_gb = ENV.fetch('VAGRANT_DISK_SIZE_GB', '50').to_i
  config.vm.provider "virtualbox" do |vb|
    disk_file = File.join(File.dirname(__FILE__), ".vagrant", "data_disk.vdi")

    # Clean up stale VirtualBox registration if file doesn't exist but is still registered
    unless File.exist?(disk_file)
      # Check if disk is registered in VirtualBox and remove stale entry
      vbox_list = `VBoxManage list hdds 2>/dev/null`
      if vbox_list.include?(disk_file)
        # Extract UUID and close the medium
        uuid_match = vbox_list.match(/UUID:\s+([a-f0-9-]+).*?Location:\s+#{Regexp.escape(disk_file)}/m)
        if uuid_match
          system("VBoxManage closemedium disk #{uuid_match[1]} --delete 2>/dev/null")
        end
      end
      vb.customize ['createhd', '--filename', disk_file, '--size', disk_size_gb * 1024]
    end
    vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                  '--port', 1, '--device', 0, '--type', 'hdd', '--medium', disk_file]
  end

  # Initialize and format D: drive (runs automatically on first boot)
  config.vm.provision "disk_setup", type: "shell" do |s|
    s.inline = <<-POWERSHELL
      $disk = Get-Disk | Where-Object PartitionStyle -eq 'RAW'
      if ($disk) {
        Write-Host "Initializing and formatting D: drive..."
        $disk | Initialize-Disk -PartitionStyle GPT -PassThru |
          New-Partition -DriveLetter D -UseMaximumSize |
          Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
        Write-Host "D: drive created successfully"
      } else {
        Write-Host "No RAW disk found or D: drive already exists"
      }
    POWERSHELL
  end

  common_env = {
    'ansible_connection'                   => 'winrm',
    'ansible_winrm_transport'              => 'basic',
    'ansible_winrm_server_cert_validation' => 'ignore',
    'ansible_winrm_scheme'                 => 'http',
    'install_drive'                        => 'D:',
    'ado_pat_token'                        => ENV.fetch('ADO_PAT_TOKEN', 'placeholder'),
  }

  # default playbook for simple testing
  config.vm.provision :ansible do |ansible|
    ansible.limit = 'all'
    ansible.galaxy_role_file = 'requirements.yml'
    ansible.playbook = 'tests/playbook.yml'
    ansible.extra_vars = common_env
  end

  # Upgrade step 1 (install older Java/Tomcat)
  config.vm.provision 'ansible_upgrade_step1', type: :ansible, run: 'never' do |ansible|
    ansible.limit = 'all'
    ansible.galaxy_role_file = 'requirements.yml'
    ansible.playbook = 'tests/playbook-upgrade.yml'
    ansible.extra_vars = common_env.merge(
      'upgrade_step' => 1,
      'tomcat_auto_start' => true
    )
  end

  # Upgrade step 2 with candidate workflow enabled (auto promote)
  config.vm.provision 'ansible_upgrade_step2', type: :ansible, run: 'never' do |ansible|
    ansible.limit = 'all'
    ansible.galaxy_role_file = 'requirements.yml'
    ansible.playbook = 'tests/playbook-upgrade.yml'
    ansible.extra_vars = common_env.merge(
      'upgrade_step' => 2,
      'tomcat_auto_start' => true,
      'tomcat_candidate_enabled' => true,
      'tomcat_candidate_delegate' => 'localhost'
    )
  end

  # Upgrade step 2 (prepare only – leaves candidate running)
  config.vm.provision 'ansible_upgrade_step2_prepare', type: :ansible, run: 'never' do |ansible|
    ansible.limit = 'all'
    ansible.galaxy_role_file = 'requirements.yml'
    ansible.playbook = 'tests/playbook-upgrade.yml'
    ansible.extra_vars = common_env.merge(
      'upgrade_step' => 2,
      'tomcat_auto_start' => true,
      'tomcat_candidate_enabled' => true,
      'tomcat_candidate_delegate' => 'localhost',
      'tomcat_candidate_manual_control' => true
    )
  end

  # Upgrade step 2 finalization (promote + cleanup)
  config.vm.provision 'ansible_upgrade_step2_finalize', type: :ansible, run: 'never' do |ansible|
    ansible.limit = 'all'
    ansible.galaxy_role_file = 'requirements.yml'
    ansible.playbook = 'tests/playbook-upgrade.yml'
    ansible.extra_vars = common_env.merge(
      'upgrade_step' => 2,
      'tomcat_auto_start' => true,
      'tomcat_candidate_enabled' => true,
      'tomcat_candidate_delegate' => 'localhost',
      'tomcat_candidate_manual_control' => false
    )
  end
  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network "forwarded_port", guest: 8080, host: 8080
  config.vm.network "forwarded_port", guest: 9080, host: 9080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
end
