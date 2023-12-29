# Terraform plan for DNS servers on Proxmox.
# ---

# Pi-Hole DNS
resource "proxmox_virtual_environment_vm" "dns" {
  for_each = var.dns

  # VM general settings
  node_name      = each.value.node
  vm_id          = each.value.id
  name           = each.key
  tags           = [var.common-dns.tag]
  description    = var.common-dns.desc
  machine        = var.common.machine
  started        = var.common.started
  reboot         = var.common.reboot

  # VM clone template
  clone {
    node_name    = var.common-dns.clone-node
    vm_id        = var.common-dns.clone-id
    datastore_id = each.value.datastore
    retries      = var.common.clone-retry
  }

  # VM cloud-init configuration
  initialization {
    datastore_id = each.value.datastore
    interface    = var.common.ci-iface
    dns {
      server     = var.common-dns.dns
      domain     = var.common.domain
    }
    ip_config {
      ipv4 {
        address  = each.value.ipv4-ip
        gateway  = each.value.ipv4-gw
      }
    }
  }

  # VM OS type
  operating_system {
    type = var.common.os-type
  }

  # VM hardware options
  bios           = var.common.bios
  cpu {
    type         = var.common.cpu-type
    sockets      = var.common.cpu-sockets
    cores        = var.common-dns.cores
  }
  memory {
    dedicated    = var.common-dns.memory
    shared       = var.common.ballon
  }
  vga {
    type         = var.common.vga-type
  }
  # VLAN DATA
  network_device {
    bridge       = var.common.bridge
    vlan_id      = var.common.vlan-id
    model        = var.common.model
    firewall     = var.common.fw
  }
  scsi_hardware  = var.common.scsihw
  disk {
    datastore_id = each.value.datastore
    file_format  = var.common.format
    interface    = var.common.interface
    size         = var.common-dns.disk-size
    ssd          = var.common.ssd
    cache        = var.common.cache
    iothread     = var.common.iothread
    discard      = var.common.discard
  }
  # VM options
  on_boot        = var.common.onboot
  boot_order     = [var.common.boot]
  agent {
    enabled      = var.common.agent
    trim         = var.common.agent-trim
  }
  tablet_device  = var.common.tablet
}
