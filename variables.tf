# ==============================================================================
# Proxmox Connection
# ==============================================================================

variable "proxmox_host" {
  description = "Proxmox host hostname or IP address"
  type        = string
}

variable "proxmox_port" {
  description = "The Proxmox API port"
  type        = number
  default     = 8006
}

variable "proxmox_tls" {
  description = "Whether to use HTTPS (true) or HTTP (false)"
  type        = bool
  default     = true
}

variable "proxmox_insecure" {
  description = "Whether to skip TLS verification"
  type        = bool
  default     = true
}

variable "proxmox_username" {
  description = "The Proxmox VE username"
  type        = string
}

variable "proxmox_password" {
  description = "The Proxmox VE password"
  type        = string
  sensitive   = true
}

locals {
  proxmox_endpoint = "${var.proxmox_tls ? "https" : "http"}://${var.proxmox_host}:${var.proxmox_port}"
}

# ==============================================================================
# Proxmox Infrastructure
# ==============================================================================

variable "proxmox_node_name" {
  description = "The name of the Proxmox node to deploy VMs on"
  type        = string
  default     = "pve"
}

variable "proxmox_disk_datastore" {
  description = "Proxmox datastore for VM disks (typically 'local-lvm')"
  type        = string
  default     = "local-lvm"
}

variable "proxmox_disk_storage_type" {
  description = "Storage type for VM disks: 'ssd' enables optimizations (discard, iothread), 'hdd' uses traditional settings"
  type        = string
  default     = "ssd"

  validation {
    condition     = contains(["ssd", "hdd"], var.proxmox_disk_storage_type)
    error_message = "Storage type must be either 'ssd' or 'hdd'."
  }
}

variable "proxmox_iso_datastore" {
  description = "Proxmox datastore for ISO storage (typically 'local')"
  type        = string
  default     = "local"
}

variable "proxmox_network_bridge" {
  description = "The network bridge to use for VM networking"
  type        = string
  default     = "vmbr0"
}

variable "proxmox_vlan_tag" {
  description = "Optional VLAN tag for VM network adapters (null = no VLAN tag)"
  type        = number
  default     = null
}

# ==============================================================================
# Network Configuration
# ==============================================================================

variable "network_gateway" {
  description = "The network gateway for VMs"
  type        = string
}

variable "nameservers" {
  description = "DNS nameservers for the Talos nodes"
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]
}

variable "starting_ip" {
  description = "Starting IP address for nodes (will be incremented sequentially. format: x.x.x.x)"
  type        = string
}

# ==============================================================================
# Talos Cluster Configuration
# ==============================================================================

variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "talos"
}

variable "cluster_endpoint" {
  description = "The cluster endpoint (VIP or load balancer for control plane)"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.11.5"
}

variable "talos_image_extensions" {
  description = "List of Talos system extensions to include in the image"
  type        = list(string)
  default     = ["siderolabs/qemu-guest-agent"]
}

# ==============================================================================
# Node Configuration
# ==============================================================================

variable "node_pools" {
  description = "Definition of node pools for the cluster"
  type = map(object({
    node_type    = string                 # "controlplane" or "worker"
    architecture = string                 # "amd64" or "arm64"
    count        = number                 # Number of nodes in this pool
    cpu_cores    = number                 # Number of CPU cores
    memory_mb    = number                 # Memory in MB
    disk_size_gb = number                 # Disk size in GB
    vlan_tag     = optional(number, null) # Optional VLAN tag override (null = use global setting)
  }))

  # https://docs.siderolabs.com/talos/v1.11/getting-started/system-requirements#minimum-requirements
  default = {
    controlplane = {
      node_type    = "controlplane"
      architecture = "amd64"
      count        = 3
      cpu_cores    = 2
      memory_mb    = 2048
      disk_size_gb = 10
    }
    workers_amd64 = {
      node_type    = "worker"
      architecture = "amd64"
      count        = 2
      cpu_cores    = 1
      memory_mb    = 1024
      disk_size_gb = 10
    }
    workers_arm64 = {
      node_type    = "worker"
      architecture = "arm64"
      count        = 0
      cpu_cores    = 1
      memory_mb    = 1024
      disk_size_gb = 10
    }
  }
}

variable "starting_vm_id" {
  description = "Starting VM ID for nodes (will be incremented sequentially)"
  type        = number
  default     = 1000
}

# ==============================================================================
# Kubernetes/CNI Configuration
# ==============================================================================

variable "install_cilium" {
  description = "Whether to install Cilium CNI via Terraform. Set to false if managing via Flux/GitOps."
  type        = bool
  default     = true
}
