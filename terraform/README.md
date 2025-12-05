# Proxmox Terraform Configuration

This Terraform configuration deploys VMs on Proxmox from ISO images.

## ISO-Based Deployment

VMs are created from scratch and boot from ISO files instead of cloning templates. This approach:
- ✅ Allows fresh OS installations
- ✅ No need to maintain VM templates
- ✅ Easy to test different OS versions
- ⚠️ Requires manual installation or automated provisioning (cloud-init)

## Files Structure

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `terraform.tfvars` - Actual variable values (gitignored)
- `terraform.tfvars.example` - Example template for variable values
- `outputs.tf` - Output definitions

## Prerequisites

1. Proxmox API token created
2. Talos Linux template created in Proxmox
3. Terraform installed

## Usage

### Initial Setup

1. Copy the example vars file (if starting fresh):
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your actual values:
   ```bash
   vim terraform.tfvars
   ```

3. Initialize Terraform:
   ```bash
   terraform init
   ```

### Deploy

1. Review the plan:
   ```bash
   terraform plan
   ```

2. Apply the configuration:
   ```bash
   terraform apply
   ```

3. View outputs:
   ```bash
   terraform output
   ```

### Destroy

To destroy the infrastructure:
```bash
terraform destroy
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `pm_api_url` | Proxmox API URL | - |
| `pm_user` | Proxmox username | - |
| `pm_password` | Proxmox password | - |
| `pm_tls_insecure` | Skip TLS verification | `true` |
| `vms` | Map of VMs to create | See below |

## Creating Multiple VMs

The configuration uses a `vms` map variable that allows you to create multiple VMs with different resources. Each VM is defined as a separate entry in the map.

### Example: 3 VMs with Different Resources (ISO-based)

```hcl
vms = {
  "talos-controlplane" = {
    node_name      = "pve"
    iso_file       = "local:iso/talos-amd64.iso"
    cores          = 4           # More powerful for control plane
    memory         = 4096
    disk_size      = 50
    disk_type      = "scsi0"
    disk_storage   = "local-lvm"
    network_model  = "virtio"
    network_bridge = "vmbr0"
  }
  "talos-worker-1" = {
    node_name      = "pve"
    iso_file       = "local:iso/talos-amd64.iso"
    cores          = 2           # Standard worker resources
    memory         = 2048
    disk_size      = 32
    disk_type      = "scsi0"
    disk_storage   = "local-lvm"
    network_model  = "virtio"
    network_bridge = "vmbr0"
  }
  "talos-worker-2" = {
    node_name      = "pve"
    iso_file       = "local:iso/talos-amd64.iso"
    cores          = 2
    memory         = 2048
    disk_size      = 32
    disk_type      = "scsi0"
    disk_storage   = "local-lvm"
    network_model  = "virtio"
    network_bridge = "vmbr0"
  }
}
```

### Per-VM Configuration Options

| Field | Description | Example |
|-------|-------------|---------|
| `node_name` | Proxmox node to deploy on | `pve` |
| `iso_file` | ISO file path in Proxmox | `local:iso/talos-amd64.iso` |
| `cores` | Number of CPU cores | `2`, `4`, `8` |
| `memory` | Memory in MB | `2048`, `4096` |
| `disk_size` | Disk size in GB | `32`, `50` |
| `disk_type` | Disk interface | `scsi0` |
| `disk_storage` | Storage location | `local-lvm` |
| `network_model` | Network model | `virtio` |
| `network_bridge` | Network bridge | `vmbr0` |

### ISO File Setup

Before deploying VMs, upload your ISO files to Proxmox:

1. **Via Web UI**: Datacenter → Storage (local) → ISO Images → Upload
2. **Via SSH**: Copy to `/var/lib/vz/template/iso/` on Proxmox host
3. **Download URL**: Use Proxmox web UI to download from URL

**ISO Path Format**: `<storage>:iso/<filename>`
- Examples: `local:iso/talos-amd64.iso`, `local:iso/ubuntu-22.04.iso`

## Managing VMs

### Add a New VM

Simply add a new entry to the `vms` map in `terraform.tfvars`:

```hcl
vms = {
  # ... existing VMs ...
  "my-new-vm" = {
    node_name      = "pve"
    iso_file       = "local:iso/talos-amd64.iso"
    cores          = 2
    memory         = 2048
    disk_size      = 32
    disk_type      = "scsi0"
    disk_storage   = "local-lvm"
    network_model  = "virtio"
    network_bridge = "vmbr0"
  }
}
```

Then run: `terraform apply`

### Remove a VM

Delete the VM entry from the `vms` map and run: `terraform apply`

**Warning**: This will destroy the VM and all its data!

### Modify VM Resources

Change the values in the VM's configuration and run: `terraform apply`

**Note**: Some changes (like CPU/memory) may require a VM restart.

### Deploy to Different Nodes

You can spread VMs across multiple Proxmox nodes:

```hcl
vms = {
  "vm-on-node-1" = {
    node_name = "pve"
    # ... rest of config
  }
  "vm-on-node-2" = {
    node_name = "pve-2"
    # ... rest of config
  }
}
```

## Security Notes

- `terraform.tfvars` is gitignored to protect sensitive credentials
- Passwords are marked as sensitive in variable definitions
- Never commit `terraform.tfvars` or `*.tfstate` files

