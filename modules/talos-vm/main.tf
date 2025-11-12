# Download Talos image to Proxmox
resource "proxmox_virtual_environment_download_file" "talos_image" {
  content_type = "iso"
  datastore_id = var.iso_datastore
  node_name    = var.node_name
  url          = var.talos_image_url

  # Ensure we only download once per image URL
  lifecycle {
    ignore_changes = [url]
  }
}

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
}

# Create the VM
resource "proxmox_virtual_environment_vm" "this" {
  name        = local.vm_name
  description = "Talos ${var.node_type} | Managed by Terraform"
  node_name   = var.node_name
  vm_id       = var.vm_id
  tags        = concat(var.tags, ["terraform", var.node_type, var.architecture])
  on_boot     = var.on_boot
  started     = true

  machine = "q35"
  bios    = "ovmf"

  cpu {
    cores   = var.cpu_cores
    sockets = var.cpu_sockets
    type    = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  # EFI disk
  efi_disk {
    datastore_id = var.disk_datastore
    file_format  = "raw"
    type         = "4m"
  }

  # Main disk
  disk {
    datastore_id = var.disk_datastore
    file_id      = proxmox_virtual_environment_download_file.talos_image.id
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = "raw"
  }

  # Network
  network_device {
    bridge  = var.network_bridge
    vlan_id = var.vlan_tag
  }

  # VGA display
  vga {
    type = "serial0"
  }

  serial_device {}

  # Initialization configuration for network
  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      servers = var.nameservers
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to the disk after initial creation
      disk,
    ]
  }
}

# Apply Talos machine configuration
resource "talos_machine_configuration_apply" "this" {
  client_configuration        = var.talos_client_config
  machine_configuration_input = var.talos_machine_config
  node                        = split("/", var.ip_address)[0]
  endpoint                    = split("/", var.ip_address)[0]

  depends_on = [proxmox_virtual_environment_vm.this]
}
