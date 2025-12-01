# Talos VM Module Variables
# Configuration for creating Proxmox VMs with Talos Linux.

# VM Identity
variable "vm_id" {
  description = "The ID of the VM"
  type        = number
}

variable "name" {
  description = "Name of the VM (optional, will be auto-generated if not provided based on node type and IP)"
  type        = string
  default     = null
}

variable "node_name" {
  description = "The name of the Proxmox node to create the VM on"
  type        = string
}

# Talos Configuration
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

variable "talos_iso_id" {
  description = "Proxmox resource ID for the Talos ISO (format: datastore:iso/filename.iso)"
  type        = string
}

# Hardware Resources
variable "cpu_cores" {
  description = "Number of CPU cores per socket"
  type        = number
  default     = 2
}

variable "cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "memory_mb" {
  description = "Memory allocation in megabytes"
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "Disk size in gigabytes for Talos installation"
  type        = number
  default     = 50
}

variable "disk_storage_type" {
  description = "Storage type: 'ssd' enables SSD optimizations (discard, iothread), 'hdd' uses traditional settings"
  type        = string
  default     = "ssd"

  validation {
    condition     = contains(["ssd", "hdd"], var.disk_storage_type)
    error_message = "Storage type must be either 'ssd' or 'hdd'."
  }
}

# Storage Configuration
variable "proxmox_disk_datastore" {
  description = "Proxmox datastore for VM disks and EFI disk"
  type        = string
}

# Network Configuration
variable "network_bridge" {
  description = "Network bridge for the VM (e.g., vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "vlan_tag" {
  description = "VLAN tag for network isolation (optional, no VLAN if not specified)"
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Static IP address to configure in CIDR notation (e.g., 10.0.20.11/24)"
  type        = string
}

variable "gateway" {
  description = "Network gateway IP address"
  type        = string
}

variable "nameservers" {
  description = "List of DNS nameserver IP addresses"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

# VM Management
variable "tags" {
  description = "Additional tags to apply to the VM (terraform, node_type, and architecture are added automatically)"
  type        = list(string)
  default     = ["talos"]
}

variable "mac_address_prefix" {
  description = "MAC address prefix for predictable addressing (first 4 octets, e.g., '00:AA:BB:CC'). Last 2 octets generated from VM ID."
  type        = string
  default     = "00:AA:BB:CC"
}

variable "on_boot" {
  description = "Automatically start VM when Proxmox node boots"
  type        = bool
  default     = true
}

variable "auto_start" {
  description = "Start the VM immediately after creation"
  type        = bool
  default     = true
}
