terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "3.0.2-rc06"
    }
  }
}

provider "proxmox" {
  pm_api_url = "https://192.168.1.100:8006/api2/json"
  pm_user = "root@pve"
  pm_password = "7csnAhdb"
#   pm_token_id = "terraform"
#   pm_token_secret = "terraform"
}
