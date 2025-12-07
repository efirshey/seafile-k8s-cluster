# Talos Cluster Configuration
# This file handles all Talos Linux cluster setup

# Generate cluster secrets (PKI, tokens, etc.)
resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

# Generate machine configuration for control plane
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_endpoint}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets
  talos_version    = var.talos_version
  kubernetes_version = var.kubernetes_version

  docs     = false
  examples = false

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = "control-plane-1"
          interfaces = [{
            interface = var.network_interface
            addresses = ["${var.controlplane_ip}/${var.network_cidr}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
          }]
          nameservers = var.nameservers
        }
        kubelet = {
          image = "ghcr.io/siderolabs/kubelet:${var.kubernetes_version}"
          defaultRuntimeSeccompProfileEnabled = true
          disableManifestsDirectory = true
        }
        install = {
          disk = var.install_disk
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
        }
      }
    })
  ]
}

# Generate machine configuration for worker nodes
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_endpoint}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets
  talos_version    = var.talos_version
  kubernetes_version = var.kubernetes_version

  docs     = false
  examples = false

  config_patches = [
    yamlencode({
      machine = {
        kubelet = {
          image = "ghcr.io/siderolabs/kubelet:${var.kubernetes_version}"
          defaultRuntimeSeccompProfileEnabled = true
          disableManifestsDirectory = true
        }
        install = {
          disk = var.install_disk
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
        }
      }
    })
  ]
}

# Apply configuration to control plane
resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [
    proxmox_virtual_environment_vm.vms
  ]

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.controlplane_ip

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = "control-plane-1"
        }
      }
    })
  ]
}

# Apply configuration to worker nodes
resource "talos_machine_configuration_apply" "workers" {
  depends_on = [
    proxmox_virtual_environment_vm.vms
  ]

  for_each = var.worker_nodes

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.ip

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.value.hostname
          interfaces = [{
            interface = var.network_interface
            addresses = ["${each.value.ip}/${var.network_cidr}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
          }]
          nameservers = var.nameservers
        }
      }
    })
  ]
}

# Bootstrap the Kubernetes cluster (only needs to run on control plane)
resource "talos_machine_bootstrap" "cluster" {
  depends_on = [
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.workers
  ]

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.controlplane_ip
}

# Retrieve the kubeconfig from the cluster
resource "talos_cluster_kubeconfig" "cluster" {
  depends_on = [
    talos_machine_bootstrap.cluster
  ]

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.controlplane_ip
}

# Generate talosconfig for cluster management
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [var.controlplane_ip]
}

