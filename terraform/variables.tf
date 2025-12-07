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

# Talos Cluster Configuration
variable "cluster_name" {
  description = "Name of the Talos Kubernetes cluster"
  type        = string
  default     = "talos-k8s-cluster"
}

variable "cluster_endpoint" {
  description = "IP address of the control plane (for API endpoint)"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.11.5"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.34.1"
}

variable "controlplane_ip" {
  description = "IP address for the control plane node"
  type        = string
}

variable "worker_nodes" {
  description = "Map of worker nodes with their IPs and hostnames"
  type = map(object({
    ip       = string
    hostname = string
  }))
}

variable "network_interface" {
  description = "Network interface name (e.g., ens18)"
  type        = string
  default     = "ens18"
}

variable "network_gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.0.1"
}

variable "network_cidr" {
  description = "Network CIDR mask (e.g., 24 for /24)"
  type        = number
  default     = 24
}

variable "nameservers" {
  description = "DNS nameservers"
  type        = list(string)
  default     = ["192.168.0.1", "8.8.8.8"]
}

variable "install_disk" {
  description = "Disk to install Talos on"
  type        = string
  default     = "/dev/sda"
}

# VM Configuration
variable "vms" {
  description = "Map of VMs to create with their configurations"
  type = map(object({
    node_name      = string
    iso_file       = string
    cores          = number
    memory         = number
    disk_size      = number
    disk_type      = string
    disk_storage   = string
    network_model  = string
    network_bridge = string
  }))
  default = {
    "talos-linux-vm" = {
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
}

