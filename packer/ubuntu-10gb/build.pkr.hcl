# Baseline Packer Build
# Ubuntu 23
# ---

packer {
  required_plugins {
    proxmox-iso = {
      version   = ">= 1.1.6"
      source    = "github.com/hashicorp/proxmox"
    }
  }
}

# Variable Definitions
variable "proxmox_hostname" {
  description = "Proxmox hostname (pve.example.com)"
  type        = string
}

variable "proxmox_api_id" {
  description = "Proxmox API ID"
  type        = string
  sensitive   = true
}

variable "proxmox_api_secret" {
  description = "Proxmox API Secret"
  type        = string
  sensitive   = true
}

variable "username" {
  description = "Default username"
  type        = string
}

variable "user_password" {
  description = "Default user password"
  type        = string
  sensitive   = true
}

variable "user_sshkey" {
  description = "Default user private ssh key"
  type        = string
  sensitive   = true
}

variable "port_min" {
  description = "Minimum http port"
  type        = number
}

variable "port_max" {
  description = "Maximum http port"
  type        = number
}

# VM Resource Definitions
source "proxmox-iso" "ubuntu-10gb" {
 
  # Proxmox Connection Settings
  proxmox_url = "https://${var.proxmox_hostname}/api2/json"
  username    = var.proxmox_api_id
  token       = var.proxmox_api_secret
  insecure_skip_tls_verify = true
 
  # VM General Settings
  node    = "hela1"
  vm_id   = "1011"
  vm_name = "ubuntu-10gb"
  template_description = "Ubuntu Base Template"

  # VM OS Settings
  iso_storage_pool = "nomad"
  iso_file         = "nomad:iso/ubuntu-server-23-4.iso"
  unmount_iso      = true
  os               = "l26"

  # VM System Settings
  bios = "ovmf"
  efi_config {
    efi_storage_pool  = "anshar"
    efi_type          = "4m"
    pre_enrolled_keys = true
  }
  machine = "q35"
  vga {
    type = "serial0"
  }
  serials = ["socket"]

  # VM Disk Settings
  scsi_controller = "virtio-scsi-single"
  disks {
    disk_size    = "10G"
    type         = "scsi"
    storage_pool = "anshar"
    format       = "raw"
    ssd          = true
    discard      = true
    cache_mode   = "none"
    io_thread    = true
  }

  # VM CPU Settings
  cpu_type = "host"
  sockets  = 1
  cores    = 4
 
  # VM Memory Settings
  memory             = 4096
  ballooning_minimum = 0

  # VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr2"
    vlan_tag = "10"
    firewall = "false"
  } 

  # VM Cloud-Init Settings
  cloud_init = true
  cloud_init_storage_pool = "anshar"

  # VM Options
  onboot     = "false"
  boot       = "order=scsi0;ide2"
  qemu_agent = true

  # Packer Boot Commands
  boot_wait    = "10s"
  boot_command = [
    "<wait><up>e<wait>",
    "<down><down><down><end><wait>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall console=ttyS0 ipv6.disable=1 ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---",
    "<wait><f10><wait>"
  ]

  # Packer Autoinstall Settings
  http_directory    = "./"
  http_bind_address = "0.0.0.0"
  http_port_min     = var.port_min
  http_port_max     = var.port_max

  # SSH config
  ssh_username = var.username
  ssh_password = var.user_password
  #ssh_private_key_file = var.user_sshkey
  ssh_timeout  = "20m"
}

# Build Definition to create the VM Template
build {

  name    = "ubuntu-10gb"
  sources = ["source.proxmox-iso.ubuntu-10gb"]

  # Upload baseline files
  provisioner "file" {
    source      = "files/"
    destination = "/tmp"
  }

  # Post provisioning the VM
  provisioner "shell" {
    execute_command = "echo '${var.user_password}' | sudo -S env {{ .Vars }} {{ .Path }}"
    inline = [
      # GRUB Configuration
      "echo '***Configuring GRUB with ttys0 and efi.***'",
      "sudo cp /tmp/grub /etc/default/grub",
      "sudo update-grub2 -o /boot/grub/grub.cfg",
      "sudo update-grub2 -o /boot/efi/EFI/ubuntu/grub.cfg",
      "sudo chmod 600 /etc/default/grub",
      "sudo chmod 600 /etc/grub.d/40_custom",
      # Package Updates and installation
      "echo '***Updating and installing baseline packages.***'",
      "sudo cp /tmp/sources.list /etc/apt/sources.list",
      "sudo apt remove intel-microcode linux-firmware wireless-regdb -y",
      "sudo apt update -y",
      "sudo apt upgrade -y",
      "sudo apt dist-upgrade -y",
      "sudo apt install cloud-init dnsutils foot-terminfo intel-microcode tar vim-tiny -y",
      # Baseline customizations
      "echo '***Baseline customizations.***'",
      "sudo cp /tmp/svc-account /etc/sudoers.d/svc-account",
      "sudo chmod 440 /etc/sudoers.d/svc-account",
      "sudo cp /tmp/sshd_config /etc/ssh/sshd_config",
      "sudo cp /tmp/ssh-banner /etc/ssh/ssh-banner",
      # Initialize cloud-init
      "echo '***Initializing cloud-init.***'",
      "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg",
      "sudo cloud-init clean --logs",
      # Cleanup VM
      "echo '***Cleaning up system.***'",
      "sudo apt autoclean -y",
      "sudo apt autoremove -y",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo truncate -s 0 /etc/resolv.conf",
      "sudo rm -f /var/lib/systemd/random-seed",
      "sudo rm -rf /root/* /tmp/* /var/tmp/*",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo sync"
    ]
  }
}
