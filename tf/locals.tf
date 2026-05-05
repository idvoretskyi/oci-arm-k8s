locals {
  # ── Cluster identity ───────────────────────────────────────────────────────────
  cluster_name = var.cluster_name

  # ── Kubernetes versions ────────────────────────────────────────────────────────
  # latest_kubernetes_version: last entry in the sorted list OCI returns.
  latest_kubernetes_version = (
    length(data.oci_containerengine_cluster_option.options.kubernetes_versions) > 0 ?
    data.oci_containerengine_cluster_option.options.kubernetes_versions[
      length(data.oci_containerengine_cluster_option.options.kubernetes_versions) - 1
    ] : null
  )

  # kubernetes_version: explicit pin wins; otherwise always-latest.
  # With null (default) every `tofu apply` upgrades the cluster when OCI
  # publishes a newer version — no manual version tracking required.
  kubernetes_version = coalesce(var.kubernetes_version, local.latest_kubernetes_version)

  # node_pool_kubernetes_version: follows cluster by default; can lag behind
  # during staged upgrades (upgrade cluster first, validate, then node pool).
  node_pool_kubernetes_version = coalesce(
    var.node_pool_kubernetes_version,
    local.kubernetes_version
  )

  # ── Resource tagging (CIS + cost tracking) ─────────────────────────────────────
  freeform_tags = {
    Environment = "demo"
    ManagedBy   = "OpenTofu"
    Purpose     = "CNCF-demo"
    CostCenter  = "free-tier"
    Cluster     = local.cluster_name
  }
}
