# Talos Kubernetes Cluster with Terraform

This Terraform configuration automates the complete deployment of a Talos Kubernetes cluster on Proxmox, from VM creation to a fully bootstrapped Kubernetes cluster.

## What This Does

This configuration:
1. ✅ Creates VMs in Proxmox (control plane + workers)
2. ✅ Boots them from Talos ISO
3. ✅ Generates cluster PKI certificates and secrets
4. ✅ Creates and applies Talos machine configurations
5. ✅ Configures static IPs and hostnames
6. ✅ Bootstraps the Kubernetes cluster
7. ✅ Outputs kubeconfig and talosconfig

**One command**: `terraform apply` → Full Kubernetes cluster ready!

## Prerequisites

### 1. Talos ISO
Upload Talos Linux ISO to Proxmox:
```bash
ssh root@192.168.0.229
cd /var/lib/vz/template/iso/
wget https://github.com/siderolabs/talos/releases/download/v1.11.5/metal-amd64.iso -O talos-linux.iso
```

### 2. Install talosctl
```bash
# macOS
brew install siderolabs/tap/talosctl

# Linux
curl -sL https://talos.dev/install | sh
```

### 3. Verify Terraform providers
The configuration uses:
- `bpg/proxmox` ~> 0.50
- `siderolabs/talos` ~> 0.6

## Configuration

### Main Configuration Files

#### 1. `terraform.tfvars` - Your Cluster Configuration

```hcl
# Talos Cluster Settings
cluster_name       = "talos-k8s-cluster"
cluster_endpoint   = "192.168.0.101"  # Control plane IP
controlplane_ip    = "192.168.0.101"
talos_version      = "v1.11.5"
kubernetes_version = "v1.34.1"

# Network Settings
network_interface = "ens18"
network_gateway   = "192.168.0.1"
network_cidr      = 24
nameservers       = ["192.168.0.1", "8.8.8.8"]
install_disk      = "/dev/sda"

# Worker Nodes - Add/remove as needed
worker_nodes = {
  "worker-1" = {
    ip       = "192.168.0.102"
    hostname = "talos-worker-1"
  }
  "worker-2" = {
    ip       = "192.168.0.103"
    hostname = "talos-worker-2"
  }
}

# VMs - Must match worker_nodes count + 1 control plane
vms = {
  "talos-controlplane" = {
    node_name      = "pve"
    iso_file       = "local:iso/talos-linux.iso"
    cores          = 4
    memory         = 4096
    disk_size      = 50
    # ...
  }
  "talos-worker-1" = { ... }
  "talos-worker-2" = { ... }
}
```

### Key Configuration Points

#### Control Plane IP
The `controlplane_ip` must match:
- The IP in your network configuration
- The `cluster_endpoint`
- Where Kubernetes API will be accessible

#### Worker Nodes
The `worker_nodes` map defines:
- **Key**: Internal identifier (used in Terraform)
- **ip**: Static IP address for the worker
- **hostname**: Hostname for the node

⚠️ **Important**: The number of VMs in `vms` must match `worker_nodes` + 1 (control plane)

#### Network Configuration
- **network_interface**: Usually `ens18` for Proxmox VirtIO
- **network_gateway**: Your network gateway
- **network_cidr**: Subnet mask (24 = /24)
- **nameservers**: DNS servers
- **install_disk**: Disk where Talos will be installed

## Deployment

### Step 1: Initialize Terraform
```bash
cd terraform
terraform init
```

This will download:
- Proxmox provider
- Talos provider

### Step 2: Review the Plan
```bash
terraform plan
```

This shows what will be created:
- 3 VMs (1 control plane + 2 workers)
- Talos machine secrets
- Machine configurations
- Cluster bootstrap

### Step 3: Deploy!
```bash
terraform apply
```

**Timeline**:
- VM creation: 1-2 minutes
- Talos boot: 2-3 minutes
- Config apply: 2-3 minutes
- Bootstrap: 3-5 minutes
- **Total: ~10-15 minutes**

### Step 4: Access Your Cluster
```bash
# Save kubeconfig
terraform output -raw kubeconfig > ~/.kube/config

# Verify cluster
kubectl get nodes

# Expected output:
# NAME              STATUS   ROLES           AGE   VERSION
# control-plane-1   Ready    control-plane   5m    v1.34.1
# talos-worker-1    Ready    <none>          4m    v1.34.1
# talos-worker-2    Ready    <none>          4m    v1.34.1
```

### Step 5: Save Talosconfig (Optional)
```bash
# For Talos management with talosctl
terraform output -raw talosconfig > ~/.talos/config

# Test Talos connection
talosctl --talosconfig ~/.talos/config health --nodes 192.168.0.101
```

## Outputs

After successful deployment, Terraform outputs:

| Output | Description |
|--------|-------------|
| `kubeconfig` | Kubernetes config for kubectl access |
| `talosconfig` | Talos config for talosctl management |
| `cluster_endpoint` | Kubernetes API endpoint URL |
| `controlplane_ip` | Control plane IP address |
| `worker_ips` | Map of worker IPs |
| `vm_details` | Proxmox VM information |
| `next_steps` | Quick start instructions |

## Scaling the Cluster

### Add Worker Nodes

1. Add to `worker_nodes` in `terraform.tfvars`:
```hcl
worker_nodes = {
  "worker-1" = { ip = "192.168.0.102", hostname = "talos-worker-1" }
  "worker-2" = { ip = "192.168.0.103", hostname = "talos-worker-2" }
  "worker-3" = { ip = "192.168.0.104", hostname = "talos-worker-3" }  # New
}
```

2. Add matching VM in `vms`:
```hcl
vms = {
  # ... existing VMs ...
  "talos-worker-3" = {
    node_name      = "pve"
    iso_file       = "local:iso/talos-linux.iso"
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

3. Apply changes:
```bash
terraform apply
```

### Remove Worker Nodes

1. Remove from both `worker_nodes` and `vms`
2. Run `terraform apply`

⚠️ **Warning**: This will destroy the VM and all data!

## Troubleshooting

### VMs Freeze at Boot
**Symptom**: VMs show "x86_64 microarchitecture level 2 or higher is required"

**Fix**: CPU type is already set to `host` in `main.tf`. Verify in Proxmox:
- VM → Hardware → Processors → Type should be `host`

### Talos Config Apply Timeout
**Symptom**: `talos_machine_configuration_apply` times out

**Causes**:
1. VMs haven't booted yet (wait longer)
2. Network issues (check IPs are correct)
3. ISO not attached properly

**Fix**: 
```bash
# Check if Talos is running
ssh root@192.168.0.229
qm list  # Verify VMs are running

# Check console
# In Proxmox Web UI: VM → Console
# Should see Talos boot messages
```

### Bootstrap Fails
**Symptom**: `talos_machine_bootstrap` fails

**Fix**:
```bash
# Manually bootstrap
talosctl bootstrap --nodes 192.168.0.101 --talosconfig <(terraform output -raw talosconfig)
```

### Network Configuration Issues
**Symptom**: Nodes can't reach each other

**Check**:
1. IPs are in correct subnet
2. Gateway is correct
3. DHCP not conflicting with static IPs

## File Structure

```
terraform/
├── main.tf              # Proxmox provider and VM resources
├── talos.tf             # Talos cluster configuration (NEW!)
├── variables.tf         # All variable definitions
├── terraform.tfvars     # Your actual configuration
├── outputs.tf           # Cluster outputs
├── README.md            # General Terraform docs
└── TALOS_SETUP.md       # This file
```

## Comparison with Manual Setup

### Before (Manual):
```bash
# 1. Create VMs manually or with Terraform
# 2. Wait for boot
talosctl get disks --insecure --nodes 192.168.0.101
# 3. Generate configs
talosctl gen config talos-k8s-cluster https://192.168.0.101:6443
# 4. Edit configs for each node
# 5. Apply to control plane
talosctl apply-config --insecure --nodes 192.168.0.101 --file controlplane.yaml
# 6. Apply to each worker
talosctl apply-config --insecure --nodes 192.168.0.102 --file worker.yaml
# 7. Bootstrap
talosctl bootstrap --nodes 192.168.0.101
# 8. Get kubeconfig
talosctl kubeconfig
```

### After (Automated):
```bash
terraform apply
terraform output -raw kubeconfig > ~/.kube/config
kubectl get nodes
```

## Advanced Configuration

### Custom Kubernetes Version
```hcl
kubernetes_version = "v1.34.1"  # Change to any supported version
```

### Custom Talos Version
```hcl
talos_version = "v1.11.5"  # Must match ISO version
```

### Multiple Control Planes (HA)
For production, use 3 or 5 control plane nodes:

1. Modify `talos.tf` to support multiple control planes
2. Add control plane IPs to cluster_endpoint with load balancer
3. Apply configs to all control planes before bootstrap

(This requires more advanced configuration - see Talos docs)

## Clean Up

To destroy everything:
```bash
terraform destroy
```

This will:
1. Delete all VMs from Proxmox
2. Remove all disks
3. Clear Terraform state

⚠️ **All data will be lost!**

## Support

- **Talos Documentation**: https://www.talos.dev/
- **Talos Provider Docs**: https://registry.terraform.io/providers/siderolabs/talos/latest/docs
- **Issues**: Check GitHub issues for both projects

## Notes

- First apply takes longer (~15 min) as Talos installs to disk
- Subsequent applies are faster
- Cluster secrets are stored in Terraform state (keep it secure!)
- Consider using Terraform Cloud or encrypted backend for production

