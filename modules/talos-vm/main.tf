# Talos VM Module
# Creates Proxmox VMs configured to boot and install Talos Linux from ISO.
# Handles MAC address generation, auto-naming, and network configuration.

# Generate VM name if not provided
locals {
  # Extract last octet from IP for node number
  node_number = tonumber(split(".", split("/", var.ip_address)[0])[3])

  # Generate name based on node type and architecture
  generated_name = var.node_type == "controlplane" ? (
    "${var.cluster_name}-cp-${local.node_number}"
    ) : (
    "${var.cluster_name}-worker-${var.architecture}-${local.node_number}"
  )

  # Use provided name or generated name
  vm_name = var.name != null ? var.name : local.generated_name

  # Generate MAC address with custom prefix and unique suffix based on VM ID
  mac_address = format("${var.mac_address_prefix}:%02X:%02X", floor(var.vm_id / 256), var.vm_id % 256)
}

# Create the VM with ISO mounted and empty disk
resource "proxmox_virtual_environment_vm" "this" {
  name        = local.vm_name
  description = "Talos ${var.node_type} | Managed by Terraform"
  node_name   = var.node_name
  vm_id       = var.vm_id
  tags        = concat(var.tags, ["terraform", var.node_type, var.architecture])
  on_boot     = var.on_boot
  started     = var.auto_start

  machine = "q35"
  bios    = "seabios"

  agent {
    enabled = true
    trim    = true
    type    = "virtio"
  }

  cpu {
    cores   = var.cpu_cores
    sockets = var.cpu_sockets
    type    = "host"
  }

  operating_system {
    type = "l26"
  }

  memory {
    dedicated = var.memory_mb
  }

  # Primary disk for Talos installation (using VirtIO Block for best performance)
  disk {
    datastore_id = var.proxmox_disk_datastore
    interface    = "virtio0"
    size         = var.disk_size_gb
    file_format  = "raw"

    # Storage-type specific optimizations
    ssd      = var.disk_storage_type == "ssd" ? true : false
    discard  = var.disk_storage_type == "ssd" ? "on" : "ignore"
    iothread = var.disk_storage_type == "ssd" ? true : false
    aio      = var.disk_storage_type == "ssd" ? "io_uring" : "threads"
    cache    = var.disk_storage_type == "ssd" ? "none" : "writethrough"
  }

  # Mount Talos ISO
  cdrom {
    file_id   = var.talos_iso_id
    interface = "ide3"
  }

  # Boot from disk first, then CDROM
  boot_order = ["virtio0", "ide3"]

  # Network
  network_device {
    bridge      = var.network_bridge
    vlan_id     = var.vlan_tag
    mac_address = local.mac_address
  }

  # Network IP configuration for first boot
  initialization {
    datastore_id = var.proxmox_disk_datastore

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }
  }

  # VGA display
  vga {
    type = "serial0"
  }

  serial_device {}

  lifecycle {
    ignore_changes = [
      started,
      disk,       # Prevent disk changes from forcing VM recreation
      boot_order, # Prevent boot order changes from forcing VM recreation
      cdrom,      # Prevent CDROM changes from forcing VM recreation
    ]
  }
}
