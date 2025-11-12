output "cache_path" {
  description = "Path to the cached image on the Proxmox host"
  value       = local.cache_path
}

output "cache_filename" {
  description = "Filename of the cached image"
  value       = local.cache_filename
}
