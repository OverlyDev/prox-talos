# Cilium Module Variables

variable "cilium_version" {
  description = "Cilium chart version to deploy"
  type        = string
}

variable "gateway_api_version" {
  description = "Gateway API CRD version to install"
  type        = string
}

variable "depends_on_resources" {
  description = "List of resources this module depends on (for dependency management)"
  type        = list(any)
  default     = []
}
