variable "talos_image_url" {
  description = "URL to the Talos image"
  type        = string
}

variable "architecture" {
  description = "CPU architecture (amd64 or arm64)"
  type        = string
}

variable "proxmox_ssh_host" {
  description = "SSH hostname or IP address of the Proxmox node"
  type        = string
}
