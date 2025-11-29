# Talos Config Module

This module generates Talos machine secrets, configurations, and client configuration for a Talos Kubernetes cluster.

## Purpose

Centralizes the creation of:
- **Machine secrets** - Cryptographic keys and tokens for cluster security
- **Machine configurations** - Base configurations for control plane and worker nodes
- **Client configuration** - talosconfig file for cluster management via `talosctl`

## How It Works

1. **Generate Secrets**: Creates a new set of machine secrets with cluster-wide cryptographic material
2. **Generate Configs**: Creates base machine configurations for control plane and worker nodes
3. **Create Client Config**: Generates talosconfig with endpoints for cluster management
4. **Output Everything**: Provides outputs that can be used by other modules for VM creation and configuration

## Key Features

### Base Configuration
The module generates base configurations with:
- **No CNI**: Sets CNI to "none" to allow custom CNI installation (Cilium, Calico, etc.)
- **Proxy Disabled**: Disables kube-proxy for use with CNI-native proxies
- **Kubernetes Version**: Configurable k8s version
- **Network Settings**: Configurable pod and service CIDRs

### Security
- All sensitive outputs (secrets, configurations) are marked `sensitive = true`
- Machine secrets are generated fresh for each cluster
- Client configuration includes proper RBAC for cluster administration

### Flexibility
- Separate control plane and worker configurations
- Supports custom config patches via parent modules
- Configurable cluster domain, CIDRs, and version

## Usage Example

```hcl
module "talos_config" {
  source = "./modules/talos-config"

  cluster_name     = "homelab"
  talos_version    = "v1.11.5"
  cluster_endpoint = "https://10.0.20.10:6443"  # VIP or load balancer

  control_plane_endpoints = [
    "10.0.20.11",
    "10.0.20.12",
    "10.0.20.13"
  ]

  all_node_addresses = [
    "10.0.20.11",
    "10.0.20.12",
    "10.0.20.13",
    "10.0.20.21",
    "10.0.20.22"
  ]

  kubernetes_version    = "1.31.1"
  cluster_pod_cidr      = "10.244.0.0/16"
  cluster_service_cidr  = "10.96.0.0/12"
}

# Use in machine configuration
resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = module.talos_config.client_configuration
  machine_configuration_input = module.talos_config.machine_configs.controlplane
  # ... additional config patches ...
}

# Save talosconfig file
resource "local_sensitive_file" "talosconfig" {
  content  = module.talos_config.talosconfig
  filename = "${path.module}/talosconfig"
}
```

## Variables

### Cluster Identity
- `cluster_name` - Name of the cluster (used in configs and kubeconfig)
- `talos_version` - Talos version (default: "v1.11.5")
- `cluster_endpoint` - Kubernetes API endpoint, usually a VIP (e.g., https://10.0.20.10:6443)

### Node Configuration
- `control_plane_endpoints` - List of control plane IPs for talosconfig
- `all_node_addresses` - All node IPs (control plane + workers) for talosconfig
- `controlplane_count` - Number of control plane nodes (default: 3)
- `worker_count` - Number of worker nodes (default: 3)

### Kubernetes Configuration
- `kubernetes_version` - Kubernetes version to install (default: "1.31.1")
- `cluster_domain` - Kubernetes DNS domain (default: "cluster.local")
- `cluster_pod_cidr` - Pod CIDR range (default: "10.244.0.0/16")
- `cluster_service_cidr` - Service CIDR range (default: "10.96.0.0/12")

## Outputs

### Sensitive Outputs
- `machine_secrets` - Raw machine secrets object
- `client_configuration` - Client config object for machine configuration apply
- `machine_configs` - Map with "controlplane" and "worker" base configurations
- `talosconfig` - Complete talosconfig file content (save to disk for `talosctl`)

### Non-sensitive Outputs
- `cluster_name` - The cluster name
- `cluster_endpoint` - The cluster endpoint
- `talos_version` - The Talos version

## Configuration Details

### Base Control Plane Config
```yaml
cluster:
  network:
    cni:
      name: none  # No CNI - install your own
  proxy:
    disabled: true  # No kube-proxy - use CNI-native proxy
```

### Base Worker Config
Standard worker configuration with no special patches applied. Custom patches should be applied in the parent module.

## Common Patterns

### Adding Custom Config Patches
```hcl
resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = module.talos_config.client_configuration
  machine_configuration_input = module.talos_config.machine_configs.controlplane

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/installer/abc123:v1.11.5"
        }
        network = {
          interfaces = [{
            interface = "eth0"
            addresses = ["10.0.20.11/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = "10.0.20.1"
            }]
          }]
          nameservers = ["1.1.1.1", "8.8.8.8"]
        }
      }
    }),
    yamlencode({
      cluster = {
        controlPlane = {
          endpoint = "https://10.0.20.10:6443"
        }
      }
    })
  ]
}
```

### Saving Configuration Files
```hcl
resource "local_sensitive_file" "talosconfig" {
  content  = module.talos_config.talosconfig
  filename = "${path.module}/talosconfig"
}

resource "local_sensitive_file" "controlplane_config" {
  content  = module.talos_config.machine_configs.controlplane
  filename = "${path.module}/controlplane.yaml"
}
```

## High Availability Considerations

### Cluster Endpoint
The `cluster_endpoint` should be a highly available endpoint:
- **VIP (Virtual IP)**: Shared IP using Talos native VIP or external load balancer
- **Load Balancer**: Hardware or software load balancer (HAProxy, MetalLB)
- **DNS Round Robin**: Less reliable, but works for simple setups

Example VIP configuration (applied separately):
```yaml
machine:
  network:
    interfaces:
      - interface: eth0
        vip:
          ip: 10.0.20.10  # VIP for control plane
```

### Control Plane Endpoints
List individual control plane node IPs for `talosctl` to connect to. The tool will try each endpoint until one responds.

## Network Configuration

### CIDR Requirements
Ensure CIDRs don't overlap:
- Node network: 10.0.20.0/24
- Pod CIDR: 10.244.0.0/16
- Service CIDR: 10.96.0.0/12

### Custom CNI Installation
After cluster bootstrap, install your CNI of choice:
```bash
# Cilium example
helm install cilium cilium/cilium --namespace kube-system \
  --set ipam.operator.clusterPoolIPv4PodCIDRList="{10.244.0.0/16}"
```

## Requirements

- Terraform >= 1.0
- siderolabs/talos provider >= 0.9.0

## Resources

- [Talos Configuration Reference](https://www.talos.dev/latest/reference/configuration/)
- [Talos Cluster Bootstrap](https://www.talos.dev/latest/introduction/getting-started/)
- [talosctl Documentation](https://www.talos.dev/latest/reference/cli/)
