# prox-talos

Terraform modules for deploying Talos Linux clusters on Proxmox VE.

## Features

- Automated Talos Linux cluster deployment on Proxmox
- Custom ISO generation via Talos Image Factory with system extensions
- Configurable node pools (control plane and workers)
- Multi-architecture support (amd64, arm64)
- VLAN tagging for network isolation
- ISO-based installation with persistent extensions
- Automatic MAC address generation and VM naming
- High availability control plane with VIP support

## Prerequisites

### Proxmox Environment
- Proxmox VE 8.0 or later
- Network configured with bridge (e.g., `vmbr0`)
- Sufficient storage for VM disks and ISO files

### Required Tools
- Terraform >= 1.0
- talosctl (Talos CLI)
- kubectl (Kubernetes CLI)
- Access to Proxmox API

This repository includes a `devenv.nix` file for automatic environment setup with all required tools:

```bash
# Install devenv (if not already installed)
# See: https://devenv.sh/getting-started/

# Enter the development environment
exec devenv shell
```

## Quick Start

### 1. Clone and Configure

```bash
git clone <your-repo>
cd prox-talos
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit Configuration

Edit `terraform.tfvars` with your environment settings. See `terraform.tfvars.example` for all available options and detailed comments.

Key settings to configure:
- Proxmox endpoint, credentials, and node name
- Network gateway, netmask, and DNS servers
- Starting IP address and VM ID for sequential assignment
- Cluster name, endpoint (VIP), and Talos version
- Node pools with desired resource allocations

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

The deployment will:
- Generate custom Talos ISOs with extensions
- Create and configure VMs with static networking
- Apply machine configurations
- Bootstrap the cluster automatically
- Generate `talosconfig` and `kubeconfig` files

### 4. Access Cluster

After deployment completes, the `talosconfig` and `kubeconfig` files are ready to use. If using `devenv`, the environment variables are set automatically. Otherwise:

```bash
export TALOSCONFIG=$(pwd)/talosconfig
export KUBECONFIG=$(pwd)/kubeconfig
```

Verify the cluster:

```bash
kubectl get nodes
talosctl health
```

## Configuration

### Node Pools

Node pools are defined in `terraform.tfvars`. Each pool can have different resource allocations and architectures. See `terraform.tfvars.example` for examples including multi-architecture setups.

### Talos Extensions

Customize system extensions in `terraform.tfvars`:

```hcl
talos_extensions = [
  "siderolabs/qemu-guest-agent",
  "siderolabs/iscsi-tools"
]
```

Available extensions: https://factory.talos.dev/

### High Availability

The cluster uses a Virtual IP (VIP) for control plane high availability. The VIP is specified in `cluster_endpoint` (e.g., `https://10.0.20.10:6443`) and is automatically configured on all control plane nodes using Talos native VIP support.

The VIP should be set to an IP address that comes before your `starting_ip_address` to avoid conflicts with node IPs.

## Architecture

### Modules

- **talos-config** - Generates Talos machine configurations, secrets, and client configuration
- **talos-image** - Builds custom Talos ISOs via Image Factory and downloads to Proxmox
- **talos-vm** - Creates and configures Proxmox VMs with static networking

### Deployment Flow

1. **Image Generation** - Creates custom Talos ISOs with extensions via factory.talos.dev
2. **ISO Download** - Proxmox downloads ISO once per architecture
3. **VM Creation** - VMs created with empty disk, ISO mounted, and cloud-init for initial networking
4. **Installation** - Talos boots from ISO and installs to disk with extensions
5. **Configuration** - Machine configuration applied with static networking and VIP
6. **Bootstrap** - First control plane node bootstraps the cluster

## Outputs

- `talosconfig` - Talos client configuration for cluster management
- `controlplane_nodes` - Control plane node details (IP, VM ID, names)
- `worker_nodes` - Worker node details
- `cluster_endpoint` - Kubernetes API endpoint

## Troubleshooting

### Check Node Status

```bash
talosctl --nodes <node-ip> get members
talosctl --nodes <node-ip> health
```

### View VM Console

Access VM console through Proxmox web UI or via VNC to see boot process.

### Check Guest Agent

```bash
# From Proxmox host
qm guest exec <vm-id> -- talosctl version
```

### Reinstall

To reinstall a node:
1. Delete the VM in Terraform or manually
2. Apply Terraform to recreate
3. Node will automatically rejoin cluster

## Clean Up

```bash
terraform destroy
```

Note: ISOs are cached and not deleted. Remove manually from Proxmox if desired.

## Module Documentation

- [talos-image](./modules/talos-image/README.md) - Custom ISO generation
- [talos-config](./modules/talos-config/README.md) - Configuration management
- [talos-vm](./modules/talos-vm/README.md) - VM creation

## Resources

- [Talos Documentation](https://www.talos.dev)
- [Talos Image Factory](https://factory.talos.dev)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
