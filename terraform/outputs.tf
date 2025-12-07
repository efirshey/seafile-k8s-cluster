# VM Outputs
output "vm_details" {
  description = "Details of all deployed VMs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vms : name => {
      vm_id     = vm.vm_id
      node_name = vm.node_name
      name      = vm.name
    }
  }
}

output "vm_ids" {
  description = "Map of VM names to their IDs"
  value       = { for name, vm in proxmox_virtual_environment_vm.vms : name => vm.vm_id }
}

# Talos Cluster Outputs
output "cluster_name" {
  description = "Name of the Talos Kubernetes cluster"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${var.cluster_endpoint}:6443"
}

output "controlplane_ip" {
  description = "Control plane node IP address"
  value       = var.controlplane_ip
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = { for k, v in var.worker_nodes : k => v.ip }
}

# Kubeconfig - Use this to access your cluster
output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value       = talos_cluster_kubeconfig.cluster.kubeconfig_raw
  sensitive   = true
}

# Talosconfig - Use this for Talos management
output "talosconfig" {
  description = "Talosconfig for Talos management"
  value       = data.talos_client_configuration.cluster.talos_config
  sensitive   = true
}

# Instructions
output "next_steps" {
  description = "Instructions for accessing your cluster"
  value = <<-EOT
    
    🎉 Talos Kubernetes Cluster Deployed Successfully!
    
    Cluster Name: ${var.cluster_name}
    API Endpoint: https://${var.cluster_endpoint}:6443
    
    📋 To access your cluster:
    
    1. Save kubeconfig:
       terraform output -raw kubeconfig > ~/.kube/config
       
    2. Verify cluster:
       kubectl get nodes
       
    3. Save talosconfig (for Talos management):
       terraform output -raw talosconfig > ~/.talos/config
       
    4. Check Talos health:
       talosctl --talosconfig ~/.talos/config health --nodes ${var.controlplane_ip}
    
    Control Plane: ${var.controlplane_ip}
    Workers: ${join(", ", [for k, v in var.worker_nodes : v.ip])}
    
  EOT
}

