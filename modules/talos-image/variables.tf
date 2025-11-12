variable "talos_version" {
  description = "Talos Linux version"
  type        = string
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

variable "platform" {
  description = "Platform type (nocloud, metal, aws, etc.)"
  type        = string
  default     = "nocloud"
}

variable "extensions" {
  description = "List of system extensions to include"
  type        = list(string)
  default     = ["siderolabs/qemu-guest-agent"]
}

variable "kernel_args" {
  description = "Extra kernel arguments"
  type        = list(string)
  default     = []
}
