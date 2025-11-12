locals {
  # Get unique architectures from node pools
  architectures = distinct([for pool in var.node_pools : pool.architecture if pool.count > 0])

  # Parse starting IP
  starting_ip_parts = split(".", var.starting_ip)
  ip_prefix         = join(".", slice(local.starting_ip_parts, 0, 3))
  starting_octet    = tonumber(local.starting_ip_parts[3])

  # Flatten node pools into individual node definitions
  nodes_raw = flatten([
    for pool_name, pool in var.node_pools : [
      for i in range(pool.count) : {
        key          = "${pool_name}-${i}"
        pool_name    = pool_name
        node_type    = pool.node_type
        architecture = pool.architecture
        pool_index   = i
      }
    ]
  ])

  # Calculate sequential IP addresses and VM IDs across all pools
  nodes = [
    for idx, node in local.nodes_raw : merge(node, {
      vm_id        = var.starting_vm_id + idx
      ip_address   = "${local.ip_prefix}.${local.starting_octet + idx}/24"
      cpu_cores    = var.node_pools[node.pool_name].cpu_cores
      memory_mb    = var.node_pools[node.pool_name].memory_mb
      disk_size_gb = var.node_pools[node.pool_name].disk_size_gb
      vlan_tag     = coalesce(var.node_pools[node.pool_name].vlan_tag, var.proxmox_vlan_tag)
    })
  ]
}

module "talos_cluster" {
  source = "./modules/talos-config"

  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  talos_version    = var.talos_version
}

# Generate Talos images for each architecture in use
module "talos_image" {
  source   = "./modules/talos-image"
  for_each = toset(local.architectures)

  talos_version = module.talos_cluster.talos_version
  architecture  = each.key
  extensions    = var.talos_image_extensions
}

# Create all VMs
module "talos_vm" {
  source   = "./modules/talos-vm"
  for_each = { for node in local.nodes : node.key => node }

  vm_id        = each.value.vm_id
  node_name    = var.proxmox_node_name
  node_type    = each.value.node_type
  architecture = each.value.architecture
  cluster_name = var.cluster_name

  talos_client_config  = module.talos_cluster.client_configuration
  talos_machine_config = each.value.node_type == "controlplane" ? module.talos_cluster.machine_configs.controlplane : module.talos_cluster.machine_configs.worker
  talos_image_url      = module.talos_image[each.value.architecture].image_url

  cpu_cores    = each.value.cpu_cores
  memory_mb    = each.value.memory_mb
  disk_size_gb = each.value.disk_size_gb

  disk_datastore = var.proxmox_vm_datastore
  iso_datastore  = var.proxmox_iso_datastore
  network_bridge = var.proxmox_network_bridge
  vlan_tag       = each.value.vlan_tag

  ip_address = each.value.ip_address
  gateway    = var.network_gateway

  # Ensure control plane nodes are created first
  depends_on = [
    module.talos_cluster
  ]
}
