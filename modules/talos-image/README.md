# Talos Image Module

This module generates custom Talos Linux ISO images using the [Talos Image Factory](https://factory.talos.dev) and downloads them to Proxmox for use in VM creation.

## Purpose

The Image Factory allows you to create customized Talos images with:
- **System extensions** (e.g., qemu-guest-agent, iscsi-tools, nvidia drivers)
- **Custom kernel arguments**
- **Multiple architectures** (amd64, arm64)
- **Different platforms** (nocloud, metal, aws, azure, etc.)

## How It Works

1. **Generate Schematic**: Sends a request to Image Factory with your desired extensions and kernel args
2. **Get Schematic ID**: Receives a unique schematic ID for your customization
3. **Build Image URLs**: Constructs URLs for both the boot ISO and installer image
4. **Download ISO**: Uses Proxmox provider to download the ISO to your specified datastore
5. **Cache Management**: ISOs are downloaded once and cached (never re-downloaded or deleted)

## Key Features

### Extension Support
The module supports official Talos extensions:
- `siderolabs/qemu-guest-agent` - QEMU guest agent for Proxmox integration (default)
- `siderolabs/iscsi-tools` - iSCSI tools for storage
- `siderolabs/nvidia-container-toolkit` - NVIDIA GPU support
- And many more from [Image Factory Extensions](https://factory.talos.dev)

### Installer Image URL
The module outputs an `installer_image` URL that points to the Image Factory installer with your schematic ID. This ensures that when Talos installs to disk, it includes all your custom extensions (not just the vanilla image).

**Critical**: Always use the `installer_image` output in your Talos machine configuration's `install.image` field to ensure extensions persist after installation.

### ISO Lifecycle Management
- ISOs are created once and never deleted
- Uses `lifecycle { ignore_changes = all }` to prevent re-downloads
- `overwrite = false` means existing ISOs are reused
- `overwrite_unmanaged = true` allows Terraform to adopt existing ISOs

## Usage Example

```hcl
module "talos_image_amd64" {
  source = "./modules/talos-image"

  talos_version = "v1.11.5"
  architecture  = "amd64"
  platform      = "nocloud"

  extensions = [
    "siderolabs/qemu-guest-agent",
    "siderolabs/iscsi-tools"
  ]

  kernel_args = [
    "console=ttyS0",
    "talos.platform=metal"
  ]

  node_name      = "prox-node1"
  iso_datastore  = "local"
}

# Use in machine config
resource "talos_machine_configuration_apply" "controlplane" {
  # ... other config ...

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/sda"
          image = module.talos_image_amd64.installer_image  # Critical: Use installer image with extensions
        }
      }
    })
  ]
}
```

## Variables

### Required
- `talos_version` - Talos Linux version (e.g., "v1.11.5")
- `node_name` - Proxmox node name where ISO should be downloaded

### Optional
- `architecture` - CPU architecture: "amd64" or "arm64" (default: "amd64")
- `platform` - Platform type: "nocloud", "metal", "aws", etc. (default: "nocloud")
- `extensions` - List of system extensions (default: ["siderolabs/qemu-guest-agent"])
- `kernel_args` - Extra kernel arguments (default: [])
- `iso_datastore` - Proxmox datastore for ISOs (default: "local")

## Outputs

- `schematic_id` - The unique schematic ID from Image Factory
- `image_url` - Full URL to the boot ISO
- `iso_id` - Proxmox resource ID (format: `datastore:iso/filename.iso`)
- `installer_image` - Image Factory installer URL with extensions (use in machine config)

## Architecture Support

The module supports creating ISOs for multiple architectures in the same Terraform configuration:

```hcl
module "talos_image_amd64" {
  source       = "./modules/talos-image"
  architecture = "amd64"
  # ... other config ...
}

module "talos_image_arm64" {
  source       = "./modules/talos-image"
  architecture = "arm64"
  # ... other config ...
}
```

## Important Notes

### Extension Persistence
Extensions are only included in the installed system if you specify the `installer_image` URL in your machine configuration. Without this, Talos will install the vanilla image and extensions will be lost after installation.

**Correct Configuration:**
```hcl
machine:
  install:
    disk: /dev/sda
    image: factory.talos.dev/installer/<schematic-id>:v1.11.5
```

### ISO Caching
ISOs are never deleted by Terraform, even on `terraform destroy`. This is intentional to prevent re-downloading large files. If you want to remove old ISOs, delete them manually from Proxmox.

### Datastore Requirements
The ISO datastore must support ISO/img content type. Typically this is the `local` datastore, but any datastore configured for ISO storage will work.

## Requirements

- Terraform >= 1.0
- hashicorp/http provider >= 3.4
- bpg/proxmox provider >= 0.86.0
- Internet access to https://factory.talos.dev

## Resources

- [Talos Image Factory Documentation](https://factory.talos.dev)
- [Talos System Extensions](https://github.com/siderolabs/extensions)
- [Talos Platform Installation Guides](https://www.talos.dev/latest/introduction/getting-started/)
