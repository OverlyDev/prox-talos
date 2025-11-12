output "vm_id" {
  description = "The ID of the VM"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "The name of the VM"
  value       = proxmox_virtual_environment_vm.this.name
}

output "node_name" {
  description = "The Proxmox node the VM is on"
  value       = proxmox_virtual_environment_vm.this.node_name
}

output "ip_address" {
  description = "The IP address of the VM"
  value       = split("/", var.ip_address)[0]
}

output "node_type" {
  description = "The type of Talos node (controlplane or worker)"
  value       = var.node_type
}

output "architecture" {
  description = "The CPU architecture (amd64 or arm64)"
  value       = var.architecture
}

output "tags" {
  description = "Tags applied to the VM"
  value       = proxmox_virtual_environment_vm.this.tags
}

output "description" {
  description = "VM description"
  value       = proxmox_virtual_environment_vm.this.description
}
