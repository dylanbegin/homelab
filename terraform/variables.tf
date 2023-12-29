# Main Terraform variables file.
# ---

# Apply to all servers
variable "common" {
  type = map(any)
  default = {
    # VM general settings
    pveurl      = "10.10.10.11:8006" #using IP here because DNS is not yet setup
    dns         = "10.10.10.31 10.10.10.32"
    domain      = "example.com" #replace with your domain
    os-type     = "l26"
    machine     = "q35"
    started     = true
    reboot      = false
    # VM hardware options
    bios        = "ovmf"
    cpu-type    = "host"
    cpu-sockets = 1
    ballon      = 0
    vga-type    = "serial0"
    # VLAN DATA
    bridge      = "vmbr2"
    vlan-id     = "10"
    model       = "virtio"
    fw          = false
    # Disk
    ci-iface    = "ide0"
    clone-retry = 3
    scsihw      = "virtio-scsi-single"
    format      = "raw"
    interface   = "scsi0"
    ssd         = true
    cache       = "none"
    iothread    = true
    discard     = "on"
    # VM options
    onboot      = true
    boot        = "scsi0"
    agent       = true
    agent-trim  = true
    tablet      = false
  }
}

# Apply to all DNS servers
variable "common-dns" {
  type = map(any)
  default = {
    tag         = "net"
    desc        = "Pi-Hole DNS<br>Rocky Linux"
    dns         = "10.10.10.1"
    clone-node  = "pve1"
    clone-id    = "1011"
    cores       = 4
    memory      = 4096
    disk-size   = 10
  }
}

# Apply to all Kubernetes servers
# Note the seperate master/worker vars
variable "common-k8s" {
  type = map(any)
  default = {
    tag           = "k8s"
    desc-master   = "Kubernetes Master<br>Rocky Linux"
    desc-worker   = "Kubernetes Worker<br>Rocky Linux"
    clone-node    = "pve1"
    clone-id      = "1051"
    cores-master  = 4
    cores-worker  = 10
    memory-master = 6144
    memory-worker = 36864
    disk-size     = 50
  }
}

# Individual DNS server configs.
variable "dns" {
  type = map(any)
  default = {
    dns1 = {
      node      = "pve1"
      id        = "131"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.31/24"
      ipv4-gw   = "10.10.10.1"
    }
    dns2 = {
      node      = "pve2"
      id        = "132"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.32/24"
      ipv4-gw   = "10.10.10.1"
    }
  }
}

# Individual Kubernetes master configs.
variable "k8s-master" {
  type = map(any)
  default = {
    rke-m1 = {
      node      = "pve1"
      id        = "141"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.41/24"
      ipv4-gw   = "10.10.10.1"
    }
    rke-m2 = {
      node      = "pve2"
      id        = "142"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.42/24"
      ipv4-gw   = "10.10.10.1"
    }
    rke-m3 = {
      node      = "pve3"
      id        = "143"
      datastore = "local-zfs"
      ipv4-ip   = "10.10.10.43/24"
      ipv4-gw   = "10.10.10.1"
    }
  }
}

# Individual Kubernetes worker configs.
variable "k8s-worker" {
  type = map(any)
  default = {
    rke-w1 = {
      node      = "pve1"
      id        = "144"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.44/24"
      ipv4-gw   = "10.10.10.1"
    }
    rke-w2 = {
      node      = "pve1"
      id        = "145"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.45/24"
      ipv4-gw   = "10.10.10.1"
    }
    rke-w3 = {
      node      = "pve1"
      id        = "146"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.46/24"
      ipv4-gw   = "10.10.10.1"
    }
    rke-w4 = {
      node      = "pve2"
      id        = "147"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.47/24"
      ipv4-gw   = "10.10.10.1"
    }
    rke-w5 = {
      node      = "pve2"
      id        = "148"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.48/24"
      ipv4-gw   = "10.10.10.1"
    }
    rke-w6 = {
      node      = "pve2"
      id        = "149"
      datastore = "anshar"
      ipv4-ip   = "10.10.10.49/24"
      ipv4-gw   = "10.10.10.1"
    }
  }
}
