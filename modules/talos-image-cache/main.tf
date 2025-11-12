locals {
  # Create a unique cache filename based on the image URL hash
  cache_filename = "talos-${var.architecture}-${substr(sha256(var.talos_image_url), 0, 16)}.raw"
  cache_path     = "/var/lib/vz/template/cache/${local.cache_filename}"
}

# Download and cache the Talos image on the Proxmox host
resource "terraform_data" "download_image" {
  triggers_replace = {
    image_url        = var.talos_image_url
    proxmox_ssh_host = var.proxmox_ssh_host
    architecture     = var.architecture
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "[Talos Cache] Checking for cached image: ${local.cache_filename}"

      # Check if the image already exists on Proxmox
      if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          root@${var.proxmox_ssh_host} \
          "test -f ${local.cache_path}"; then
        echo "[Talos Cache] Image already cached, skipping download"
        exit 0
      fi

      echo "[Talos Cache] Downloading and caching image..."

      # Download, decompress, and save to cache directory
      curl -fsSL "${var.talos_image_url}" | xz -d | \
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          root@${var.proxmox_ssh_host} \
          "cat > ${local.cache_path}"

      echo "[Talos Cache] Image cached successfully at ${local.cache_path}"
    EOT
  }

  # Optional: Clean up on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "[Talos Cache] Note: Cached image not removed from Proxmox host"
      echo "[Talos Cache] Manually remove if needed from /var/lib/vz/template/cache/"
    EOT
  }
}
