# Introduction

> :warning: This repo is new and still under early development!

This document serves as the main procedure reference for the homelab deployment and management. Much of this is automated using [Packer](https://www.packer.io/), [Terraform](https://www.terraform.io/), and [Ansible](https://www.ansible.com/). The general workflow for deployment will be:
1. Build physical servers that cannot be automated.
1. Configure automation controller and prepare the environment for automation.
1. Build packer images which will be used for VM images.
1. Build VM infrastructure with Terraform.
1. Configure VM's with Anisble such as DNS servers, and K8s cluster.
1. Automate updates and backups with Ansible.

## Goals
There are several key goals that are achieved in this project which are listed below.
- Automation: Automate everything that is possible, because who wants to do manual work??
- Security focus: Maintain security best practices. Align within reason to zero trust and FedRAMP low/moderate. Primary security controls such as:
  - All external access with be configured with SSO. SSO will require MFA.
  - Certificate management. Validated external certs and internal PKE.
  - Central logging and managment.
  - Automated updates.
  - All data in transit will be encrypted.
  - All data at rest will be encrypted.
  - All servers will be hardended to CIS/STIGS.
  - One on-prem backup, and at least one cloud bakup.
- Principle of Minimal: Combining the principles of Least Privilege, Least Effort, Minimal Codebase, and even Hotelling's Law. This priciple ensures uniformity, always minimal OS's, software with smaller codebase (where possible) and in general bloatfree. This helps with both automation and security.

## Prerequisites
Some things must be setup manunally before the automation can take over. This section will describe the steps needed before the automation can begin.
- All systems must have a FQDN set with the domain of the internal domain that you own. For example:
    - Use `example.com` for applications external access via a loadbalancer or reverse proxy.
    - Use `example.org` for the server FQDN domain.
    - Both domains must be owned by your organization. **Never use domains you do not own!**
- All servers must have a static IP.
- All servers must point to the internal DNS servers.
- All servers must use `pool.ntp.org` as it's NTP server.

Additionaly this repo already assumes you have a basic understanding of:
- Linux and Linux commands.
- Packer and Terraform.
- Ansible.

## Switching
Switches should be loaded from a backup config file. However, the general settings should be setup with the follwoing config.
- Enforce HTTPS with TLS 1.2 access and disable HTTP.
- Ensure admin access is only allowed on DATA VLAN.
- Set VLAN's as follow:
    - 02: TRANSIT (used by modem and WAN ports)
    - 10: DATA (used by server ports)
    - 20: CLIENTS (used by endpoint ports)
    - 99: DROP (Special PVID for hypervisors software VLAN ports)
- Enable STP with RSTP and disable forward BPDU.
- Enable IGMP snooping. Disable MLD snooping (we are not using IPv6).
- Disable LLDP on all TRANSIT VLAN.
- Disable DHCP L2 relay on TRANSIT VLAN.

## TODO: Add HA firewall documentation

## Physical Servers
- Ensure all physical servers are pre-boot hardended. Follow the (TODO: link document)[Preboot Hardneing](https://github.com/dylanbegin/homelab) procedure for details.
- Additionaly, GPU servers need to have IOMMU, SR-IOV, VFIO, and VT-d features enabled (this will vary based on Motherboard). Also, check the iGPU and descrete GPU configuration in BIOS.

### Storage servers
The storage server of choice is TrueNas Scale. This offers several benefits, ZFS, NFS, and S3 capabilities which will be needed for our K8s cluster. Both the primary server and backup server will use TrueNas Scale.
- Install with UEFI.
- Configure a single encrypted ZFS pool.
    - Raid level can be Z1 but do not use a VDEV more than 8 wide.
    - Name the pool `zpool`.
    - Set compression to `lz4`.
    - Set `Atime` to off.
    - Set ZFS deduplication to off.
    - Set checksum to on.
    - Set Record Size to `128k`.
- Configure NFS dataset. This will serve as the hypervisors ISO and VM backups.
    - Inherit all permissions from parent.
    - Set ZFS Encryption.
        - Type: Passphrase and save to the password manager.
        - pbkdf2iters: `350000`
        - Algorithm: `AES-256-GCM`
        - Encrypt child datasets: `yes`
- Configure S3 dataset. (TODO: add documentation)
- Congifure NFS Share.
    - Enabled: `yes`
    - Mapall Users: `root`
    - Mapall Groups: `wheel`
    - Hosts: Include only hypervisor IPs.

### Hypervisors
The hypervisors of choice is Proxmox PVE. Xen would be the preferred choice, however, further development is still needed for GPU passthrough, ZFS, and Terraform providers.
- OS disk Install.
    - 2 disk.
    - ZSF mirror
    - Set `ashift=12`
    - Enable checksum
    - Disable deduplication.
- Data storage.
    - All other disk.
    - ZFS Z1 or Z2
    - Set `ashift=12`
    - Enable checksum
    - Disable deduplication.
- ZFS tuning.
    - Root dataset: `zfs set compress=lz4 xattr=sa atime=off {pool/data}`
    - VM dataset: `zfs set compress=lz4 xattr=sa atime=off dnodesize=auto recordsize=64k {pool/data}`
    - VM dataset encryption: `zfs create -o encryption=on -o keyformat=passphrase -o keylocation=prompt {pool/data}`
    - Get status: `zpool status && zpool list && zfs list && zfs get compression && zfs get encryption && df -h`
- Configure with GPU.
    - Configure grub with `GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction nofb nomodeset initcall_blacklist=sysfb_init"`
    - Configure `/etc/kernel/cmdline` with: `root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction nofb nomodeset initcall_blacklist=sysfb_init`
    - Update `/etc/modules` for VFIO:
    ```vim
    vfio
    vfio_iommu_type1
    vfio_pci
    vfio_virqfd
    ```
    - Add IOMMU mappings:
        - `echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf`
        - `echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf`
    - Blacklist GPU drivers in `/etc/modprobe.d/blacklist.conf`
    ```vim
    blacklist radeon
    blacklist nouveau
    blacklist nvidia
    blacklist snd_hda_intel
    ```
    - Add GPU to VFIO
        - Find the GPU with `lspci -v`
        - Get vendor ID's with `lspci -n -s [gpu-id]`
        - Update `vfio.conf` with: `echo "options vfio-pci ids=[vendor-id1],[vendor-id2...] disable_vga=1"> /etc/modprobe.d/vfio.conf`
    - Updating boot:
        - Update grub: `update-grub2`
        - Update initramfs:`update-initramfs -u`
        - Update efiboot: `pve-efiboot-tool` then reboot
- Cluster all hypervisors.
- Create identical data zpools across all PVE nodes. This is an important step for Terraform.
- Connect the cluster to the NFS share created in TrueNAS.
- TODO: Add networking setup.

### Control Node
This is a VM that will manage all automation. It will have SSH access and be used to build Packer, Terraform, and Ansible.
1. [Hashicorp Packer](https://developer.hashicorp.com/packer/install) installed.
  1. Port `8082` open for image https server access.
1. [Hashicorp Terraform](https://developer.hashicorp.com/terraform/install) installed.
1. [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) installed.

#### Secrets files
Create a seperate secerets directory outside of this git, add following files, and fill out the information as needed.
- Create a Packer vars file named `creds.pkrvars.hcl`
```hcl
# This is a sensative file. Do not share!
# All variables for all Packer files.
# ---

proxmox_hostname = "pve1.example.com:8006"
proxmox_api_id = "root@pam!build"
proxmox_api_secret = "API-KEY"
username = "SVC-ACCOUNT"
user_password = "REPLACE"
user_sshkey = "/path/to/priv/key"
port_min = 8082
port_max = 8082
```
- Create a Terraform vars file named `creds.tfvars`
```hcl
# This is a sensative file. Do not share!
# All variables for all Terraform files.
# ---

pve_api_token = "root@pam!build=API-KEY"
ciuser    = "SVC-ACCOUNT"
cipass    = "REPLACE"
cissh     = "REPLACE WITH PUBLIC SSH KEY"
```
- Create an Ansible config file named `ansible.cfg`
```ini
[defaults]
inventory = /path/to/host.ini
remote_user = SVC-ACCOUNT
private_key_file = /path/to/ssh-priv-key
host_key_checking = false
scp_if_ssh = true
```
- Create an Ansible vault key file named `anisble-key` and place the vault key in this file.
- There are additional secrets files in Ansible role `vars` directory named `secrets.yml`. These need to be customized and encrypted with vault.

## Automation
Now that the systems are installed and configured the next step is to start the build process using automation.

Go through these files an make sure you change all DNS, IPs, user information, and other variables to match your environment. These should be identified by all caps or with example.com.

SSH into the control node and continue below: `ssh [user]@[controlnode]`

### Build a Packer Image
Before Terraform can build out the infrastructure, the VM images must be built first. To do this use the following:
1. Go into image directory you want to build: `cd ~/homelab/packer/{image-dir}`
1. Update all Packer modules: `packer init -upgrade build.pkr.hcl`
1. Validate image build: `packer validate -var-file={path/to/secrets/}creds.pkrvars.hcl build.pkr.hcl`
1. Run the image build: `packer build -var-file={path/to/secrets/}creds.pkrvars.hcl build.pkr.hcl`

### Build Process For Terraform
Now that the images are ready, Terraform can build out the infrastructure. In this stage Terraform will first build the VM's then it will run all the needed Ansible playbooks which configures the VM's for the rest of the cloud infrastructure.
1. Go into Terraform directory: `cd ~/homelab/terraform`
1. Initiate the workspace: `terraform init`
1. Validate the build: `terraform plan -var-file={path/to/secrets/}creds.tfvars`
1. Run the build: `terraform apply -var-file={path/to/secrets/}creds.tfvars -parallelism=2`

### Ansible Deployment
With all infrastructure deployed we are ready to configure the VMs.
1. Go ino your secrets directory: `cd /path/to/secrets/`
1. Copy the config file to you home directory: `cp ansible.cfg ~/`
1. Unlock all vault files: `ansible-vault decrypt --vault-password-file /path/to/secrets/ansible-key ~/homelab/ansible/{path/to/secrets.yml}`
1. Run the deployment playbook: `ansible-playbook ~/homelab/ansible/deploy.yml`

## TODO: Add update and backup automation documentation.
