# Proxmox Provider Configuration
variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "pm_user" {
  description = "Proxmox username (e.g. root@pam)"
  type        = string
  sensitive   = true
}

variable "pm_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

# VM Configuration
variable "vms" {
  description = "Map of VMs to create with their configurations"
  type = map(object({
    node_name    = string
    clone_vm_id  = number
    cores        = number
    memory       = number
    disk_size    = number
    disk_type    = string
    disk_storage = string
    network_model = string
    network_bridge = string
  }))
  default = {
    "talos-linux-vm" = {
      node_name      = "pve-1"
      clone_vm_id    = 102
      cores          = 2
      memory         = 2048
      disk_size      = 32
      disk_type      = "scsi0"
      disk_storage   = "local-lvm"
      network_model  = "virtio"
      network_bridge = "vmbr0"
    }
  }
}

