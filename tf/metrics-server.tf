# ── Metrics Server ────────────────────────────────────────────────────────────────
# Deployed via Helm for idempotency and version control.
# Enables `kubectl top nodes/pods`. Multi-arch image runs natively on arm64.

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.13.0"
  namespace  = "kube-system"

  # ARM-compatible: the official chart multi-arch image includes linux/arm64.
  # kubelet-insecure-tls required for OKE node TLS setup.
  set = [
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    },
    {
      name  = "resources.requests.cpu"
      value = "20m"
    },
    {
      name  = "resources.requests.memory"
      value = "32Mi"
    },
    {
      name  = "resources.limits.cpu"
      value = "100m"
    },
    {
      name  = "resources.limits.memory"
      value = "128Mi"
    },
  ]

  depends_on = [oci_containerengine_node_pool.arm_pool]
}
