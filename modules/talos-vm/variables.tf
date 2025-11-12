variable "vm_id" {
  description = "The ID of the VM"
  type        = number
}

variable "name" {
  description = "Name of the VM (optional, will be auto-generated if not provided)"
  type        = string
  default     = null
}

variable "node_name" {
  description = "The name of the Proxmox node to create the VM on"
  type        = string
}

variable "node_type" {
  description = "Type of Talos node (controlplane or worker)"
  type        = string

  validation {
    condition     = contains(["controlplane", "worker"], var.node_type)
    error_message = "Node type must be either 'controlplane' or 'worker'."
  }
}

variable "architecture" {
  description = "CPU architecture (amd64 or arm64)"
  type        = string
  default     = "amd64"

  validation {
    condition     = contains(["amd64", "arm64"], var.architecture)
    error_message = "Architecture must be either 'amd64' or 'arm64'."
  }
}

variable "cluster_name" {
  description = "Name of the cluster (used for auto-generated VM names)"
  type        = string
  default     = "talos"
}

variable "talos_client_config" {
  description = "Talos client configuration (from talos_machine_secrets)"
  type        = any
  sensitive   = true
}

variable "talos_machine_config" {
  description = "Talos machine configuration for this node"
  type        = string
  sensitive   = true
}

variable "talos_image_url" {
  description = "URL to the Talos image"
  type        = string
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 50
}

variable "disk_datastore" {
  description = "Datastore for the VM disks and EFI disk"
  type        = string
  default     = "local-lvm"
}

variable "iso_datastore" {
  description = "Datastore for ISO/image downloads (can be different from disk_datastore)"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Network bridge for the VM"
  type        = string
  default     = "vmbr0"
}

variable "vlan_tag" {
  description = "VLAN tag for the network adapter (optional, no VLAN if not specified)"
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Static IP address in CIDR format (e.g., 10.0.0.10/24)"
  type        = string
}

variable "gateway" {
  description = "Network gateway"
  type        = string
}

variable "nameservers" {
  description = "DNS nameservers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "tags" {
  description = "Tags to apply to the VM"
  type        = list(string)
  default     = ["talos"]
}

variable "on_boot" {
  description = "Start VM on Proxmox node boot"
  type        = bool
  default     = true
}
