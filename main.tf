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

  control_plane_endpoints = [for node in local.nodes : split("/", node.ip_address)[0] if node.node_type == "controlplane"]
  all_node_addresses      = [for node in local.nodes : split("/", node.ip_address)[0]]
}

# Generate Talos images and download ISOs for each architecture in use
module "talos_image" {
  source   = "./modules/talos-image"
  for_each = toset(local.architectures)

  talos_version = module.talos_cluster.talos_version
  architecture  = each.key
  extensions    = var.talos_image_extensions
  node_name     = var.proxmox_node_name
  iso_datastore = var.proxmox_iso_datastore
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

  talos_iso_id = module.talos_image[each.value.architecture].iso_id

  cpu_cores    = each.value.cpu_cores
  memory_mb    = each.value.memory_mb
  disk_size_gb = each.value.disk_size_gb

  proxmox_disk_datastore = var.proxmox_disk_datastore
  disk_storage_type      = var.proxmox_disk_storage_type
  network_bridge         = var.proxmox_network_bridge
  vlan_tag               = each.value.vlan_tag

  ip_address = each.value.ip_address
  gateway    = var.network_gateway

  # Auto-start VMs
  auto_start = true

  # Ensure control plane nodes are created first
  depends_on = [
    module.talos_cluster,
    module.talos_image
  ]
}

# Apply Talos machine configuration to nodes
resource "talos_machine_configuration_apply" "nodes" {
  for_each = { for node in local.nodes : node.key => node }

  client_configuration        = module.talos_cluster.client_configuration
  machine_configuration_input = each.value.node_type == "controlplane" ? module.talos_cluster.machine_configs.controlplane : module.talos_cluster.machine_configs.worker

  # Use static IP from cloud-init initialization
  node     = split("/", each.value.ip_address)[0]
  endpoint = split("/", each.value.ip_address)[0]

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda"
          image = module.talos_image[each.value.architecture].installer_image
        }
        network = {
          hostname = module.talos_vm[each.key].name
          interfaces = [
            merge(
              {
                interface = "eth0"
                dhcp      = false
                addresses = [each.value.ip_address]
                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = var.network_gateway
                  }
                ]
              },
              # Add VIP only for control plane nodes
              each.value.node_type == "controlplane" ? {
                vip = {
                  ip = split(":", replace(var.cluster_endpoint, "https://", ""))[0]
                }
              } : {}
            )
          ]
          nameservers = var.nameservers
        }
      }
    })
  ]

  depends_on = [module.talos_vm]
}

# Bootstrap the cluster (run once on first control plane node)
resource "talos_machine_bootstrap" "this" {
  client_configuration = module.talos_cluster.client_configuration
  node                 = split("/", local.nodes[0].ip_address)[0]
  endpoint             = split("/", local.nodes[0].ip_address)[0]

  lifecycle {
    ignore_changes = all
  }

  depends_on = [talos_machine_configuration_apply.nodes]
}

# Generate kubeconfig after bootstrap
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = module.talos_cluster.client_configuration
  node                 = split("/", local.nodes[0].ip_address)[0]

  depends_on = [talos_machine_bootstrap.this]
}

# Write talosconfig to file (workspace-specific)
resource "local_file" "talosconfig" {
  content         = module.talos_cluster.talosconfig
  filename        = "${path.module}/talosconfig${terraform.workspace != "default" ? "-${terraform.workspace}" : ""}"
  file_permission = "0600"
}

# Write kubeconfig to file (workspace-specific)
resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.module}/kubeconfig${terraform.workspace != "default" ? "-${terraform.workspace}" : ""}"
  file_permission = "0600"
}

# Merge kubeconfig into a single file for easy context switching
resource "terraform_data" "merge_kubeconfig" {
  triggers_replace = {
    kubeconfig_content = local_file.kubeconfig.content
    cluster_name       = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      # Create or update merged kubeconfig
      if [ -f "${path.module}/kubeconfig" ]; then
        KUBECONFIG="${path.module}/kubeconfig:${local_file.kubeconfig.filename}" kubectl config view --flatten > "${path.module}/kubeconfig.tmp"
        mv "${path.module}/kubeconfig.tmp" "${path.module}/kubeconfig"
      else
        cp "${local_file.kubeconfig.filename}" "${path.module}/kubeconfig"
      fi
      chmod 600 "${path.module}/kubeconfig"
      echo "[Kubeconfig] Merged ${terraform.workspace} context into kubeconfig"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      # Remove this workspace's context from merged kubeconfig
      if [ -f "${path.module}/kubeconfig" ]; then
        # Get the context to delete
        CONTEXT=$(KUBECONFIG="${path.module}/kubeconfig" kubectl config get-contexts -o name | grep "${self.triggers_replace.cluster_name}" | head -n1)
        if [ -n "$CONTEXT" ]; then
          # Check if this is the current context
          CURRENT=$(KUBECONFIG="${path.module}/kubeconfig" kubectl config current-context 2>/dev/null)

          # Delete the context, cluster, and user
          kubectl --kubeconfig="${path.module}/kubeconfig" config delete-context "$CONTEXT" 2>/dev/null || true
          kubectl --kubeconfig="${path.module}/kubeconfig" config delete-cluster "${self.triggers_replace.cluster_name}" 2>/dev/null || true
          kubectl --kubeconfig="${path.module}/kubeconfig" config unset "users.$CONTEXT" 2>/dev/null || true

          # If we deleted the current context, switch to another one
          if [ "$CURRENT" = "$CONTEXT" ]; then
            OTHER=$(KUBECONFIG="${path.module}/kubeconfig" kubectl config get-contexts -o name 2>/dev/null | head -n1)
            if [ -n "$OTHER" ]; then
              kubectl --kubeconfig="${path.module}/kubeconfig" config use-context "$OTHER" 2>/dev/null || true
            fi
          fi

          echo "[Kubeconfig] Removed context from merged config"
        fi

        # If no contexts remain, delete the file
        REMAINING=$(KUBECONFIG="${path.module}/kubeconfig" kubectl config get-contexts -o name 2>/dev/null | wc -l)
        if [ "$REMAINING" -eq 0 ]; then
          rm -f "${path.module}/kubeconfig"
          echo "[Kubeconfig] Removed merged config (no contexts remain)"
        fi
      fi
    EOT
  }

  depends_on = [local_file.kubeconfig]
}

# Merge talosconfig into a single file for easy context switching
resource "terraform_data" "merge_talosconfig" {
  triggers_replace = {
    talosconfig_content = local_file.talosconfig.content
    cluster_name        = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      # Merge talosconfig using talosctl
      # Remove existing context first to avoid duplicates on re-apply
      if [ -f "${path.module}/talosconfig" ]; then
        # Get current context
        CURRENT=$(talosctl config contexts --talosconfig "${path.module}/talosconfig" 2>/dev/null | awk '$1=="*" {print $2}')

        # If we're trying to remove the current context, switch to another first
        if [ "$CURRENT" = "${var.cluster_name}" ]; then
          # Get list of all contexts (handle both * and non-* rows)
          CONTEXTS=$(talosctl config contexts --talosconfig "${path.module}/talosconfig" 2>/dev/null | awk 'NR>1 {if($1=="*") print $2; else print $1}')
          OTHER=$(echo "$CONTEXTS" | grep -v "^${var.cluster_name}$" | head -n1)
          if [ -n "$OTHER" ]; then
            talosctl config context "$OTHER" --talosconfig "${path.module}/talosconfig" 2>/dev/null || true
          fi
        fi

        # Try to remove the context if it exists
        talosctl config remove "${var.cluster_name}" --talosconfig "${path.module}/talosconfig" -y 2>/dev/null || true
      fi
      talosctl config merge "${local_file.talosconfig.filename}" --talosconfig "${path.module}/talosconfig"
      chmod 600 "${path.module}/talosconfig"
      echo "[Talosconfig] Merged ${terraform.workspace} context into talosconfig"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      # Remove this workspace's context from merged talosconfig
      if [ -f "${path.module}/talosconfig" ]; then
        # Get all contexts (handle both * and non-* rows)
        CONTEXTS=$(talosctl config contexts --talosconfig "${path.module}/talosconfig" 2>/dev/null | awk 'NR>1 {if($1=="*") print $2; else print $1}')
        CURRENT=$(talosctl config contexts --talosconfig "${path.module}/talosconfig" 2>/dev/null | awk '$1=="*" {print $2}')
        CONTEXT_COUNT=$(echo "$CONTEXTS" | grep -v '^$' | wc -l | tr -d ' ')

        # If this is the only context left, just delete the file
        if [ "$CONTEXT_COUNT" -eq 1 ]; then
          rm -f "${path.module}/talosconfig"
          echo "[Talosconfig] Removed merged config (last context)"
        else
          # If this is the current context and there are others, switch first
          if [ "$CURRENT" = "${self.triggers_replace.cluster_name}" ]; then
            OTHER=$(echo "$CONTEXTS" | grep -v "^${self.triggers_replace.cluster_name}$" | head -n1)
            if [ -n "$OTHER" ]; then
              talosctl config context "$OTHER" --talosconfig "${path.module}/talosconfig" 2>/dev/null || true
            fi
          fi

          # Remove the context
          talosctl config remove "${self.triggers_replace.cluster_name}" --talosconfig "${path.module}/talosconfig" -y 2>/dev/null || true
          echo "[Talosconfig] Removed context from merged config"
        fi
      fi
    EOT
  }

  depends_on = [local_file.talosconfig]
}

# Wait for Kubernetes API to be ready
resource "terraform_data" "wait_for_k8s_api" {
  triggers_replace = {
    bootstrap_id = talos_machine_bootstrap.this.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      echo "[K8s] Waiting for Kubernetes API to be ready..."

      export KUBECONFIG=${local_file.kubeconfig.filename}

      for i in {1..60}; do
        if kubectl get nodes &>/dev/null; then
          echo "[K8s] Kubernetes API is ready!"
          exit 0
        fi
        echo "[K8s] Attempt $i/60: API not ready yet, waiting 5 seconds..."
        sleep 5
      done

      echo "[K8s] ERROR: Kubernetes API did not become ready after 5 minutes"
      exit 1
    EOT
  }

  depends_on = [
    talos_machine_bootstrap.this,
    local_file.kubeconfig
  ]
}

# Install Cilium CNI (optional - can be managed via Flux instead)
resource "helm_release" "cilium" {
  count = var.install_cilium ? 1 : 0

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.18.3"
  namespace  = "kube-system"

  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }

  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }

  set {
    name  = "securityContext.capabilities.ciliumAgent"
    value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
  }

  set {
    name  = "securityContext.capabilities.cleanCiliumState"
    value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
  }

  set {
    name  = "cgroup.autoMount.enabled"
    value = "false"
  }

  set {
    name  = "cgroup.hostRoot"
    value = "/sys/fs/cgroup"
  }

  set {
    name  = "k8sServiceHost"
    value = replace(replace(var.cluster_endpoint, "https://", ""), ":6443", "")
  }

  set {
    name  = "k8sServicePort"
    value = "6443"
  }

  depends_on = [
    terraform_data.wait_for_k8s_api
  ]
}
