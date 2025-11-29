# Talos Image Module
# Generates custom Talos ISO images using Image Factory with specified extensions.
# Downloads the ISO to Proxmox for use in VM creation.

# Generate schematic from Image Factory
data "http" "image_factory_schematic" {
  url    = "https://factory.talos.dev/schematics"
  method = "POST"

  request_headers = {
    Content-Type = "application/json"
  }

  request_body = jsonencode({
    customization = merge(
      {
        systemExtensions = {
          officialExtensions = var.extensions
        }
      },
      length(var.kernel_args) > 0 ? {
        extraKernelArgs = var.kernel_args
      } : {}
    )
  })
}

locals {
  schematic_id   = jsondecode(data.http.image_factory_schematic.response_body).id
  image_url      = "https://factory.talos.dev/image/${local.schematic_id}/${var.talos_version}/${var.platform}-${var.architecture}.iso"
  cache_filename = "talos-${var.talos_version}-${var.architecture}.iso"
}

# Download and cache the Talos ISO on the Proxmox node
resource "proxmox_virtual_environment_download_file" "talos_iso" {
  node_name    = var.node_name
  content_type = "iso"
  datastore_id = var.iso_datastore

  url       = local.image_url
  file_name = local.cache_filename

  # Set to true to re-download on every apply, false to keep cached ISO
  overwrite = false

  # Allow Terraform to manage ISOs that already exist (e.g., from previous runs)
  overwrite_unmanaged = true

  lifecycle {
    # Create once, then ignore changes - never delete
    ignore_changes = all
  }
}
