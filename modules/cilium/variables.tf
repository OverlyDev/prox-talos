# Cilium Module Variables

variable "cilium_version" {
  description = "Cilium chart version to deploy"
  type        = string
}

variable "gateway_api_version" {
  description = "Gateway API CRD version to install"
  type        = string
}

variable "gateway_api_channel" {
  description = "Gateway API release channel: 'standard' (stable) or 'experimental' (includes GRPCRoute, TCPRoute, TLSRoute, UDPRoute)"
  type        = string
  validation {
    condition     = contains(["standard", "experimental"], var.gateway_api_channel)
    error_message = "gateway_api_channel must be either 'standard' or 'experimental'"
  }
}

variable "depends_on_resources" {
  description = "List of resources this module depends on (for dependency management)"
  type        = list(any)
  default     = []
}
