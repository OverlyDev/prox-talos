# Cilium CNI Module

Deploys Cilium CNI with Gateway API support on Talos Linux clusters.

## Features

- Installs Gateway API CRDs (v1.2.1)
- Deploys Cilium with kube-proxy replacement
- Talos-specific configuration (cgroup, capabilities)
- Gateway API support with ALPN enabled for gRPC/TLS
- KubePrism integration (localhost:7445)

## Configuration

This module is configured for Talos Linux with:
- `kubeProxyReplacement=true` - Cilium replaces kube-proxy
- `k8sServiceHost=localhost` and `k8sServicePort=7445` - Uses KubePrism
- Talos-specific security context capabilities
- Gateway API enabled with ALPN for gRPC support

## Known Issues

When using with Talos, ensure your machine config has:
```yaml
machine:
  features:
    hostDNS:
      forwardKubeDNSToHost: false
```

This prevents issues with CoreDNS when Cilium's `bpf.masquerade=true` is enabled.

## References

- [Talos Cilium Deployment Guide](https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium)
- [Cilium Documentation](https://docs.cilium.io/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
