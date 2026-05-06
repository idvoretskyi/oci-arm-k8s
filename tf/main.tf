# ── Monitoring ────────────────────────────────────────────────────────────────────
# kube-prometheus-stack (Grafana + Prometheus + Alertmanager).
# Sized for the demo node: 2 OCPU / 12 GB ARM.
# Grafana admin password must be supplied — see variables.tf.

module "monitoring" {
  source = "../modules/monitoring"

  create_storage_class   = true
  storage_class          = "oci-bv-paravirtualized"
  grafana_admin_password = local.effective_grafana_password

  depends_on = [
    oci_containerengine_node_pool.arm_pool,
  ]
}
