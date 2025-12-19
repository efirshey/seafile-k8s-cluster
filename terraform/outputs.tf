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

output "vm_status" {
  description = "Status information for all VMs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vms : name => {
      vm_id     = vm.vm_id
      node_name = vm.node_name
      name      = vm.name
      started   = vm.started
    }
  }
}

