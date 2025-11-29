terraform {
  required_version = ">= 1.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.86.0"
    }
  }
}
