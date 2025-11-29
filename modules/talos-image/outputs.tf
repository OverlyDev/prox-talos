# Talos Image Module Outputs
# Provides schematic ID, image URLs, and ISO resource ID for VM creation.

output "schematic_id" {
  description = "Image Factory schematic ID"
  value       = local.schematic_id
}

output "image_url" {
  description = "URL to the Talos image"
  value       = local.image_url
}

output "iso_id" {
  description = "The ID of the downloaded ISO file in Proxmox"
  value       = proxmox_virtual_environment_download_file.talos_iso.id
}

output "installer_image" {
  description = "The Image Factory installer image URL with extensions"
  value       = "factory.talos.dev/installer/${local.schematic_id}:${var.talos_version}"
}
