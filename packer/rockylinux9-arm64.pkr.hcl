variable "vm_name" {
  type    = string
  default = "rockylinux9-arm64"
}

variable "iso_url" {
  type    = string
  default = "https://download.rockylinux.org/pub/rocky/9/isos/aarch64/Rocky-9-latest-aarch64-minimal.iso"
}

variable "iso_checksum" {
  type    = string
  default = "file:https://download.rockylinux.org/pub/rocky/9/isos/aarch64/CHECKSUM"
}

locals {
  qemu_binary = "${fileexists("/opt/homebrew/bin/qemu-system-aarch64") ? "/opt/homebrew/bin/qemu-system-aarch64" : "qemu-system-aarch64"}"
}

source "qemu" "rocky" {
  accelerator      = "hvf"
  qemu_binary      = local.qemu_binary
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  vm_name          = var.vm_name
  output_directory = "output/${var.vm_name}"
  disk_size        = 20480
  format           = "qcow2"
  headless         = true
  http_directory   = "${path.root}/http"

  machine_type   = "virt"
  cpu_count      = 4
  memory         = 4096

  communicator   = "ssh"
  ssh_username   = "vagrant"
  ssh_password   = "vagrant"
  ssh_timeout    = "30m"

  boot_wait    = "5s"
  boot_command = [
    "<up><wait>",
    "<tab>",
    " inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/kickstart.cfg",
    "<enter>"
  ]
}

build {
  sources = [
    "source.qemu.rocky"
  ]

  provisioner "shell" {
    inline = [
      "sudo dnf -y install cloud-utils-growpart",
      "sudo dnf -y install python3 sudo",
      "sudo systemctl disable firewalld",
      "sudo dnf clean all"
    ]
  }

  post-processor "vagrant" {
    keep_input_artifact = false
    output              = "boxes/${var.vm_name}.box"
  }
}
