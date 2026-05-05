# ── Monitoring ────────────────────────────────────────────────────────────────────
# kube-prometheus-stack (Grafana + Prometheus + Alertmanager).
# Sized for the demo node: 2 OCPU / 12 GB ARM.
# Grafana admin password must be supplied — see variables.tf.

module "monitoring" {
  source = "../modules/monitoring"

  cluster_id             = oci_containerengine_cluster.arm_cluster.id
  create_storage_class   = true
  storage_class          = "oci-bv"
  grafana_admin_password = var.grafana_admin_password

  depends_on = [
    oci_containerengine_node_pool.arm_pool,
    helm_release.metrics_server,
  ]
}
