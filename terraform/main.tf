terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true
}

resource "proxmox_virtual_environment_vm" "axion17" {
  vm_id     = 222
  node_name = "axion-pve"
  name      = "axion17"

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores   = 2
    sockets = 1
  }

  memory {
    dedicated = 4096
  }

  disk {
    size         = 32
    interface    = "scsi0"
    datastore_id = "local-lvm"
  }
  network_device {
    bridge = "vmbr0"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "192.168.1.222/24"
        gateway = "192.168.1.1"
      }
    }

    dns {
      servers = ["192.168.1.1"]
    }


    user_account {
      username = "ansible"

      keys = [trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))]
    }
  }
}