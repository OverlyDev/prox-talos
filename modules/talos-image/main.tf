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
  schematic_id = jsondecode(data.http.image_factory_schematic.response_body).id
  image_url    = "https://factory.talos.dev/image/${local.schematic_id}/${var.talos_version}/${var.platform}-${var.architecture}.iso"
  # Include schematic ID in filename so different schematics create different files
  iso_filename = "talos-${var.talos_version}-${var.architecture}-${local.schematic_id}.iso"
}

# Download the Talos ISO to the Proxmox node
resource "proxmox_virtual_environment_download_file" "talos_iso" {
  node_name    = var.node_name
  content_type = "iso"
  datastore_id = var.iso_datastore

  url       = local.image_url
  file_name = local.iso_filename

  # Don't re-download if file already exists with same name
  overwrite = false

  # Allow Terraform to manage ISOs that already exist
  overwrite_unmanaged = true
}
