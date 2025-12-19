terraform {
    required_providers {
        proxmox = {
            source  = "bpg/proxmox"
            version = "~> 0.50"
        }
    }
}

provider "proxmox" {
    endpoint  = var.pm_api_url
    username  = var.pm_user
    password  = var.pm_password
    insecure  = var.pm_tls_insecure
}

resource "proxmox_virtual_environment_vm" "vms" {
    for_each = var.vms
    stop_on_destroy = false

    name      = each.key
    node_name = each.value.node_name

    # Boot from ISO instead of cloning
    cdrom {
        file_id = each.value.iso_file
    }

    cpu {
        cores = each.value.cores
        type  = "host"
    }

    memory {
        dedicated = each.value.memory
    }

    disk {
        datastore_id = each.value.disk_storage
        file_format  = "raw"
        interface    = each.value.disk_type
        size         = each.value.disk_size
        discard      = "on"
    }

    network_device {
        model  = each.value.network_model
        bridge = each.value.network_bridge
    }

    # Start VM after creation (will boot from ISO)
    started = true
}
