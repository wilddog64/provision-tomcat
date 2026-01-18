# Kitchen Vagrantfile snippet to add D: drive
# This is included by kitchen-vagrant when vagrantfiles option is set

Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |vb|
    # Create secondary disk for D: drive
    # Store disk in project's .kitchen directory (parent of vagrant/)
    project_root = File.dirname(__dir__)
    kitchen_dir = File.join(project_root, ".kitchen")
    instance_name = ENV['KITCHEN_INSTANCE_NAME'] || 'default'
    disk_file = File.join(kitchen_dir, "data_disk_#{instance_name}.vdi")

    puts "==> Vagrantfile-disk.rb: disk_file = #{disk_file}"
    puts "==> Vagrantfile-disk.rb: project_root = #{project_root}"
    puts "==> Vagrantfile-disk.rb: Dir.pwd = #{Dir.pwd}"

    # Ensure .kitchen directory exists
    FileUtils.mkdir_p(kitchen_dir) unless File.directory?(kitchen_dir)

    unless File.exist?(disk_file)
      puts "==> Creating new disk: #{disk_file}"
      vb.customize ['createhd', '--filename', disk_file, '--size', 50 * 1024]
    else
      puts "==> Disk already exists: #{disk_file}"
    end
    vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                  '--port', 1, '--device', 0, '--type', 'hdd', '--medium', disk_file]
  end

  # Format D: drive on first boot (run: always because Kitchen may skip initial provisioning)
  config.vm.provision "disk_setup", type: "shell", run: "always", inline: <<-POWERSHELL
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
