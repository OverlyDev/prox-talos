variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version to use"
  type        = string
  default     = "v1.11.5"
}

variable "cluster_endpoint" {
  description = "The endpoint for the Talos cluster (e.g., https://10.0.0.10:6443)"
  type        = string
}

variable "control_plane_endpoints" {
  description = "List of control plane node endpoints"
  type        = list(string)
  default     = []
}

variable "all_node_addresses" {
  description = "List of all node IP addresses (control plane + workers)"
  type        = list(string)
  default     = []
}

variable "controlplane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.31.1"
}

variable "cluster_domain" {
  description = "Cluster domain for Kubernetes services"
  type        = string
  default     = "cluster.local"
}

variable "cluster_pod_cidr" {
  description = "Pod CIDR for the cluster"
  type        = string
  default     = "10.244.0.0/16"
}

variable "cluster_service_cidr" {
  description = "Service CIDR for the cluster"
  type        = string
  default     = "10.96.0.0/12"
}
