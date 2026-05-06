output "monitoring_namespace" {
  value = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "helm_release_name" {
  value = helm_release.kube_prometheus_stack.name
}

output "helm_release_version" {
  value = helm_release.kube_prometheus_stack.version
}

output "helm_release_status" {
  value = helm_release.kube_prometheus_stack.status
}

output "prometheus_service_name" {
  value = "${var.release_name}-kube-prom-prometheus"
}

output "grafana_service_name" {
  value = "${var.release_name}-grafana"
}

output "grafana_admin_password" {
  value     = var.grafana_admin_password
  sensitive = true
}

output "grafana_url" {
  value = var.grafana_ingress_enabled ? "https://${var.grafana_hostname}" : "kubectl port-forward -n ${kubernetes_namespace_v1.monitoring.metadata[0].name} svc/${var.release_name}-grafana 3000:80"
}

output "prometheus_url" {
  value = var.prometheus_ingress_enabled ? "https://${var.prometheus_hostname}" : "kubectl port-forward -n ${kubernetes_namespace_v1.monitoring.metadata[0].name} svc/${var.release_name}-kube-prom-prometheus 9090:9090"
}

output "storage_class" {
  value = var.storage_class
}

output "monitoring_endpoints" {
  value = {
    grafana_service    = "${var.release_name}-grafana.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local"
    prometheus_service = "${var.release_name}-kube-prom-prometheus.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local"
  }
}

output "grafana_ingress_hostname" {
  value = var.grafana_ingress_enabled ? var.grafana_hostname : null
}

output "prometheus_ingress_hostname" {
  value = var.prometheus_ingress_enabled ? var.prometheus_hostname : null
}
