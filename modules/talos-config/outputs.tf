output "machine_secrets" {
  description = "Machine secrets for the Talos cluster"
  value       = talos_machine_secrets.cluster.machine_secrets
  sensitive   = true
}

output "client_configuration" {
  description = "Talos client configuration object for machine configuration apply"
  value       = talos_machine_secrets.cluster.client_configuration
  sensitive   = true
}

output "machine_configs" {
  description = "Machine configurations for control plane and worker nodes"
  value = {
    controlplane = data.talos_machine_configuration.controlplane.machine_configuration
    worker       = data.talos_machine_configuration.worker.machine_configuration
  }
  sensitive = true
}

output "talosconfig" {
  description = "Talos client configuration"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the cluster"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Cluster endpoint"
  value       = var.cluster_endpoint
}

output "talos_version" {
  description = "Talos version"
  value       = var.talos_version
}
