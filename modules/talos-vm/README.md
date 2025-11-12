# Talos VM Module

This module creates Proxmox VMs with Talos Linux pre-installed using raw disk images.

## Approach

This module uses the **raw disk image** approach (nocloud platform) which is the recommended method for Talos on Proxmox. This approach:

- Downloads compressed raw disk images (`.raw.xz`)
- Imports them directly as VM disks
- Boots immediately into Talos (no installation step required)
- Is more efficient and deterministic

## Requirements

### SSH Key-Based Authentication

Due to limitations in the Proxmox Terraform provider, this module uses `local-exec` provisioners to download and import raw disk images. This requires **passwordless SSH access** from your Terraform host to your **Proxmox node** (not the VMs).

**Setup Steps:**

1. Generate an SSH key if you don't have one:
   ```bash
   ssh-keygen -t ed25519 -C "terraform@proxmox"
   ```

2. Copy your public key to the Proxmox node (use the actual Proxmox host, not VM IPs):
   ```bash
   ssh-copy-id root@<proxmox-host>  # Use the same host as proxmox_host variable
   ```

3. Test the connection:
   ```bash
   ssh root@<proxmox-host> "qm list"
   ```

**Important:**
- The module connects to the **Proxmox host** (not the VMs being created)
- Uses the same `proxmox_host` variable for both API and SSH connections
- SSH access is needed for `root` user to run `qm importdisk` commands
- Your SSH key should be in the default location (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`)### Required Tools

On your Terraform host machine:
- `curl` - for downloading images
- `xz` - for decompressing `.xz` files
- `ssh` - for connecting to Proxmox

Install on macOS:
```bash
brew install xz
```

Install on Linux:
```bash
apt-get install xz-utils  # Debian/Ubuntu
yum install xz             # RHEL/CentOS
```

## How It Works

1. **Download & Import**: Downloads the Talos raw image and pipes it through SSH to `qm importdisk`
2. **Create VM**: Creates the VM with EFI disk and network configuration
3. **Attach Disk**: Attaches the imported disk to the VM and resizes it
4. **Start VM**: Starts the VM, which boots into Talos (initially using DHCP)
5. **Apply Config**: Applies the Talos machine configuration with static network settings

### Network Configuration

VMs initially boot with DHCP to become reachable, then the Talos machine configuration applies static IP settings. For this to work smoothly:

**Option 1: DHCP Reservations (Recommended)**
- Configure your DHCP server to assign the correct IPs based on MAC address
- VMs will get the right IP immediately on first boot
- Talos config can apply without issues

**Option 2: Manual Discovery**
- VMs boot with random DHCP IPs
- You'll need to find the DHCP IPs and apply config manually first:
  ```bash
  # Find the DHCP IP from Proxmox console or DHCP logs
  talosctl apply-config --insecure --nodes <dhcp-ip> --file <machine-config>
  ```
- After config is applied, VM switches to static IP

**Option 3: Accept Retries**
- Terraform may need multiple applies if the IP isn't immediately reachable
- The `talos_machine_configuration_apply` resource will retry automatically

## Variables

See `variables.tf` for all available options. Key variables:

- `talos_image_url` - URL to the Talos nocloud raw disk image
- `disk_size_gb` - Size to resize the disk to (must be >= image size)
- `vlan_tag` - Optional VLAN tag for network isolation

## Limitations

- Requires SSH access to Proxmox nodes
- Uses `local-exec` provisioners (not pure Terraform)
- VM IPs must be routable from the Terraform host
- Cannot easily rollback disk imports

## Alternative: ISO Approach

If SSH access is not feasible, you can use the ISO/metal platform approach instead:
1. Change `platform = "metal"` in the talos-image module
2. Use `cdrom` blocks instead of disk imports
3. Talos will install on first boot (slower but no SSH required)
