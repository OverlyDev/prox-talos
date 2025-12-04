# Talos Config Module Variables
# Configuration for generating Talos cluster secrets and machine configurations.

# Cluster Identity
variable "cluster_name" {
  description = "Name of the Talos cluster (used in kubeconfig and talosconfig)"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version to generate configuration for"
  type        = string
  default     = "v1.11.5"
}

variable "cluster_endpoint" {
  description = "The Kubernetes API endpoint (usually the VIP or load balancer, e.g., https://10.0.20.10:6443)"
  type        = string
}

# Node Configuration
variable "control_plane_endpoints" {
  description = "List of control plane node endpoints for talosconfig (used for talosctl commands)"
  type        = list(string)
  default     = []
}

variable "all_node_addresses" {
  description = "List of all node IP addresses for talosconfig (control plane + workers)"
  type        = list(string)
  default     = []
}

variable "controlplane_count" {
  description = "Number of control plane nodes in the cluster"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes in the cluster"
  type        = number
  default     = 3
}

# Kubernetes Configuration
variable "kubernetes_version" {
  description = "Kubernetes version to install on the cluster"
  type        = string
  default     = "1.31.1"
}

variable "cluster_domain" {
  description = "Cluster domain for Kubernetes DNS (cluster.local is standard)"
  type        = string
  default     = "cluster.local"
}

variable "cluster_pod_cidr" {
  description = "Pod CIDR range for the cluster (must not overlap with node network)"
  type        = string
  default     = "10.244.0.0/16"
}

variable "cluster_service_cidr" {
  description = "Service CIDR range for the cluster (must not overlap with node or pod networks)"
  type        = string
  default     = "10.96.0.0/12"
}

variable "cni_name" {
  description = "CNI to use: 'flannel' (Talos-managed), 'custom', or 'none'"
  type        = string
  default     = "flannel"
}

variable "disable_kube_proxy" {
  description = "Disable kube-proxy deployment. Set to true when using a CNI that replaces kube-proxy (e.g., Cilium with kubeProxyReplacement)."
  type        = bool
  default     = false
}
