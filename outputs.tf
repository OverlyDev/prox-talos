output "talosconfig" {
  description = "Talos client configuration - save this to ~/.talos/config"
  value       = module.talos_cluster.talosconfig
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the Talos cluster"
  value       = module.talos_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Cluster endpoint URL"
  value       = module.talos_cluster.cluster_endpoint
}

output "nodes" {
  description = "All node information grouped by pool"
  value = {
    for pool_name, pool in var.node_pools : pool_name => {
      for node in local.nodes : node.key => {
        vm_id        = module.talos_vm[node.key].vm_id
        name         = module.talos_vm[node.key].name
        ip_address   = module.talos_vm[node.key].ip_address
        node_name    = module.talos_vm[node.key].node_name
        node_type    = module.talos_vm[node.key].node_type
        architecture = module.talos_vm[node.key].architecture
        tags         = module.talos_vm[node.key].tags
      } if node.pool_name == pool_name
    }
  }
}

output "controlplane_ips" {
  description = "Control plane node IP addresses"
  value = [
    for node in local.nodes : split("/", node.ip_address)[0]
    if node.node_type == "controlplane"
  ]
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value = [
    for node in local.nodes : split("/", node.ip_address)[0]
    if node.node_type == "worker"
  ]
}

output "all_node_ips" {
  description = "All node IP addresses"
  value = [
    for node in local.nodes : split("/", node.ip_address)[0]
  ]
}
