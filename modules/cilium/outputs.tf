# Cilium Module Outputs

output "cilium_installed" {
  description = "Indicates that Cilium has been installed (use for dependencies)"
  value       = terraform_data.cilium.id
}

output "gateway_api_installed" {
  description = "Indicates that Gateway API CRDs have been installed (use for dependencies)"
  value       = terraform_data.gateway_api_crds.id
}
