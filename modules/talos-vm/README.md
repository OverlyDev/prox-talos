# Talos VM Module

This module creates Proxmox VMs configured to boot and install Talos Linux from an ISO image.

## Approach

This module uses the **ISO-based installation** approach which is the standard method for Talos on Proxmox. This approach:

- Mounts a Talos ISO (with custom extensions via Image Factory)
- Creates an empty disk for installation
- Boots from ISO on first run and installs Talos to disk
- Uses cloud-init for initial network configuration
- Supports custom extensions (like qemu-guest-agent) that persist after installation

## Architecture

The module creates VMs with:
- **Boot order**: Disk first (scsi0), then ISO (ide3) as fallback
- **Initial boot**: Uses ISO to install Talos to disk with proper extensions
- **Subsequent boots**: Boots from installed disk with all extensions intact
- **Network**: Static IP configuration via cloud-init initialization block

## Key Features

### MAC Address Generation
- Automatically generates predictable MAC addresses from VM IDs
- Format: `{prefix}:XX:XX` where last two octets are derived from VM ID
- Customizable prefix via `mac_address_prefix` variable

### Auto-naming
- Control plane nodes: `{cluster_name}-cp-{node_number}`
- Worker nodes: `{cluster_name}-worker-{architecture}-{node_number}`
- Node number extracted from last octet of IP address
- Can override with custom name via `name` variable

### Extension Support
- ISO includes custom extensions (e.g., qemu-guest-agent)
- Extensions persist after installation when installer image URL is properly configured

## Network Configuration

VMs are configured with static IPs from the start using cloud-init:
- Initial IP assigned via `initialization` block
- No DHCP required
- Talos machine config applied with matching static network settings
- Gateway and nameservers configured automatically

## Variables

See `variables.tf` for all available options. Key variables:

### Required
- `vm_id` - Unique VM identifier
- `node_name` - Proxmox node to create VM on
- `node_type` - Either "controlplane" or "worker"
- `talos_iso_id` - Proxmox ISO resource ID
- `ip_address` - Static IP in CIDR notation
- `gateway` - Network gateway
- `proxmox_disk_datastore` - Datastore for VM disk

### Optional
- `name` - Custom VM name (auto-generated if not provided)
- `architecture` - CPU architecture (default: "amd64")
- `cluster_name` - Cluster name for auto-naming (default: "talos")
- `cpu_cores` / `cpu_sockets` - CPU configuration
- `memory_mb` - Memory allocation (default: 4096)
- `disk_size_gb` - Disk size (default: 50)
- `vlan_tag` - VLAN ID for network isolation
- `mac_address_prefix` - MAC address prefix (default: "00:AA:BB:CC")
- `tags` - Additional tags for the VM
- `on_boot` - Start VM on Proxmox boot (default: true)
- `auto_start` - Start VM after creation (default: true)

## Outputs

- `vm_id` - The VM ID
- `name` - VM name
- `node_name` - Proxmox node
- `ip_address` - Static IP address
- `mac_address` - Generated MAC address
- `node_type` - Type (controlplane/worker)
- `architecture` - CPU architecture
- `tags` - Applied tags

## Requirements

- Terraform >= 1.0
- Proxmox provider >= 0.86.0
- Talos provider >= 0.9.0
