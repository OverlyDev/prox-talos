# Cilium CNI Module
# Deploys Cilium with Gateway API support on Talos Linux

# Install Gateway API CRDs (required for Cilium Gateway API support)
resource "terraform_data" "gateway_api_crds" {
  triggers_replace = {
    # Using timestamp ensures this runs on every apply to maintain desired state
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      echo "[Gateway API] Installing ${var.gateway_api_channel} CRDs version ${var.gateway_api_version}..."

      # Delete existing Gateway API CRDs to ensure clean state when switching channels
      kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml --ignore-not-found=true
      kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/experimental-install.yaml --ignore-not-found=true

      # Install selected channel
      kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/${var.gateway_api_channel}-install.yaml

      echo "[Gateway API] CRDs installed successfully"
    EOT
  }
}

# Deploy Cilium CNI via helm CLI
resource "terraform_data" "cilium" {
  triggers_replace = {
    gateway_api_id = terraform_data.gateway_api_crds.id
    cilium_version = var.cilium_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      echo "[Cilium] Installing Cilium ${var.cilium_version}..."

      # Add Cilium Helm repo
      helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
      helm repo update

      # Install Cilium with Talos-specific configuration
      # See: https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium
      helm upgrade --install \
        cilium \
        cilium/cilium \
        --version ${var.cilium_version} \
        --namespace kube-system \
        --set ipam.mode=kubernetes \
        --set kubeProxyReplacement=true \
        --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
        --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
        --set cgroup.autoMount.enabled=false \
        --set cgroup.hostRoot=/sys/fs/cgroup \
        --set k8sServiceHost=localhost \
        --set k8sServicePort=7445 \
        --set gatewayAPI.enabled=true \
        --set gatewayAPI.enableAlpn=true \
        --set gatewayAPI.enableAppProtocol=true \
        --wait \
        --timeout 10m

      echo "[Cilium] Installed successfully"
    EOT
  }

  depends_on = [
    terraform_data.gateway_api_crds
  ]
}
