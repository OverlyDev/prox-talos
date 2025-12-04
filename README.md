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

Note: If using VSCode and having trouble with the Terraform extension:
- Close VSCode
- Enter the devenv shell
- Launch VSCode from that shell via `code .`

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

## Managing Multiple Clusters

This project supports managing multiple clusters using Terraform workspaces. Each workspace maintains separate state and generates workspace-specific configuration files.

### Setting Up Multiple Clusters

1. **Create cluster configuration files** (e.g., `cluster-prod.tfvars`, `cluster-staging.tfvars`) with different settings for each cluster:
   - Different IP ranges (`starting_ip`, `cluster_endpoint`)
   - Different node counts and resources
   - Different cluster names
   - Different `starting_vm_id`

2. **Create Terraform workspaces**:
   ```bash
   terraform workspace new prod
   terraform workspace new staging
   terraform workspace list  # verify workspaces
   ```

3. **Deploy and manage clusters** by selecting the workspace and corresponding var file:
   ```bash
   # Deploy production cluster
   terraform workspace select prod
   terraform apply -var-file="cluster-prod.tfvars"

   # Deploy staging cluster
   terraform workspace select staging
   terraform apply -var-file="cluster-staging.tfvars"

   # Destroy a cluster
   terraform workspace select staging
   terraform destroy -var-file="cluster-staging.tfvars"
   ```

### Configuration Files Generated

- **Default workspace**: `kubeconfig`, `talosconfig`
- **Named workspaces**: `kubeconfig-prod`, `talosconfig-prod`, etc.
- **Merged configs**: `kubeconfig` and `talosconfig` (automatically merged from all workspaces)

### Switching Between Clusters

Use the merged configuration files to easily switch between clusters:

```bash
export KUBECONFIG=$(pwd)/kubeconfig
export TALOSCONFIG=$(pwd)/talosconfig

# Switch kubectl context
kubectl config get-contexts
kubectl config use-context admin@talos-prod

# Switch talosctl context
talosctl config contexts
talosctl config context talos-prod
```

## Variable Files

Since `*.tfvars` files are gitignored, feel free to create as many as necessary to better organize your environment.

Example structure:

- `<proxmox-hostname>.tfvars` - Variables specific to a given Proxmox host (IP, credentials, datastore, bridge, etc.)
- `cluster-<name>.tfvars` - Variables specific to each cluster (cluster_name, cluster_endpoint, starting_ip, starting_vm_id, node_pools, etc.)
- `common.auto.tfvars` - (Optional) Variables common to all clusters and Proxmox hosts (e.g. `network_gateway`, `vlan_tag`, etc. )

**Important**: Any `*.auto.tfvars` files are automatically loaded by Terraform. When using workspaces for multiple clusters, avoid putting cluster-specific settings in `*.auto.tfvars` files; use explicitly named files like `cluster-prod.tfvars` instead and specify them with `-var-file`.

This setup provides flexibility to mix and match Proxmox hosts and cluster configurations by pointing `-var-file` args to the desired combination. When managing multiple clusters, remember to always select the appropriate workspace first (see [Managing Multiple Clusters](#managing-multiple-clusters)).

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

### CNI (Container Network Interface)

By default, the cluster is configured with **Flannel** as the CNI, which is automatically installed and managed by Talos during cluster bootstrap. Flannel provides a simple, reliable networking solution to get your cluster operational immediately.

You can customize the CNI configuration by setting the `cni_name` variable in your `terraform.tfvars`:

```hcl
cni_name = "flannel"  # Default: Talos-managed Flannel
# cni_name = "none"   # No CNI - manage manually or via Flux/GitOps
# cni_name = "custom" # Provide custom CNI manifests
```

If you prefer to use a different CNI (Cilium, Calico, etc.), set `cni_name = "none"` and deploy your preferred CNI after cluster creation via kubectl, Helm, or Flux. The cluster will be ready to accept any CNI that suits your requirements.

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
- `kubeconfig` - Kubernetes client configuration for cluster access
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

## Module Documentation

- [talos-image](./modules/talos-image/README.md) - Custom ISO generation
- [talos-config](./modules/talos-config/README.md) - Configuration management
- [talos-vm](./modules/talos-vm/README.md) - VM creation

## Resources

- [Talos Documentation](https://www.talos.dev)
- [Talos Image Factory](https://factory.talos.dev)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
