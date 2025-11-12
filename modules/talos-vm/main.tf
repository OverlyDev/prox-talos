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

# Create the VM (without disks initially, we'll attach them after)
resource "proxmox_virtual_environment_vm" "this" {
  name        = local.vm_name
  description = "Talos ${var.node_type} | Managed by Terraform"
  node_name   = var.node_name
  vm_id       = var.vm_id
  tags        = concat(var.tags, ["terraform", var.node_type, var.architecture])
  on_boot     = var.on_boot
  started     = false

  machine = "q35"
  bios    = "ovmf"

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

  memory {
    dedicated = var.memory_mb
  }

  # EFI disk
  efi_disk {
    datastore_id = var.disk_datastore
    file_format  = "raw"
    type         = "4m"
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

  lifecycle {
    ignore_changes = [
      disk,
      started,
    ]
  }
}

# Import the Talos disk image from cache (after VM is created)
resource "terraform_data" "import_talos_disk" {
  depends_on = [proxmox_virtual_environment_vm.this]

  triggers_replace = {
    vm_id      = var.vm_id
    cache_path = var.talos_image_cache
    node_name  = var.node_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "[Talos] Importing disk image from cache for VM ${var.vm_id}..."

      # Import the disk directly from the cached image
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${var.proxmox_ssh_host} \
        "qm importdisk ${var.vm_id} ${var.talos_image_cache} ${var.disk_datastore} --format raw"

      echo "[Talos] Disk import completed for VM ${var.vm_id}"
    EOT
  }
}

# Attach and configure the imported disk
resource "terraform_data" "attach_and_start" {
  depends_on = [
    proxmox_virtual_environment_vm.this,
    terraform_data.import_talos_disk
  ]

  triggers_replace = {
    vm_id = var.vm_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "[Talos] Configuring disk for VM ${var.vm_id}..."

      # Attach the imported disk to scsi0
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${var.proxmox_ssh_host} \
        "qm set ${var.vm_id} --scsi0 ${var.disk_datastore}:vm-${var.vm_id}-disk-1"

      # Resize the disk to the desired size
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${var.proxmox_ssh_host} \
        "qm resize ${var.vm_id} scsi0 ${var.disk_size_gb}G"

      # Set boot order
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${var.proxmox_ssh_host} \
        "qm set ${var.vm_id} --boot order=scsi0"

      # Start the VM if auto_start is enabled
      if [ "${var.auto_start}" = "true" ]; then
        echo "[Talos] Starting VM ${var.vm_id}..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          root@${var.proxmox_ssh_host} \
          "qm start ${var.vm_id} || true"

        echo "[Talos] Waiting for VM ${var.vm_id} to boot and get DHCP IP..."
        sleep 30

        echo "[Talos] VM ${var.vm_id} configured and started"
      else
        echo "[Talos] VM ${var.vm_id} configured (not started)"
      fi
    EOT
  }
}

# Wait for guest agent to report IP address
data "external" "guest_ip" {
  program = ["bash", "-c", <<-EOT
    for i in {1..30}; do
      IP=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${var.proxmox_ssh_host} \
        "qm guest cmd ${var.vm_id} network-get-interfaces 2>/dev/null" | \
        jq -r '.[] | select(.name=="eth0") | ."ip-addresses"[]? | select(."ip-address-type"=="ipv4") | ."ip-address"' | \
        grep -v '^127\.' | head -1 || echo "")

      if [ -n "$IP" ]; then
        echo "{\"ip\":\"$IP\"}"
        exit 0
      fi
      sleep 2
    done

    echo "{\"ip\":\"${split("/", var.ip_address)[0]}\"}"
  EOT
  ]

  depends_on = [terraform_data.attach_and_start]
}

# Note: Talos machine configuration is applied in main.tf after VMs start
