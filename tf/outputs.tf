# ── Cluster ───────────────────────────────────────────────────────────────────────

output "cluster_id" {
  description = "OCID of the OKE cluster."
  value       = oci_containerengine_cluster.arm_cluster.id
}

output "cluster_name" {
  description = "Display name of the OKE cluster."
  value       = oci_containerengine_cluster.arm_cluster.name
}

output "api_endpoint" {
  description = "Kubernetes API endpoint (sensitive)."
  value       = oci_containerengine_cluster.arm_cluster.endpoints[0].kubernetes
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl for the cluster."
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.arm_cluster.id} --file ~/.kube/config --region ${local.effective_region} --token-version 2.0.0 --context-name ${oci_containerengine_cluster.arm_cluster.name}"
}

# ── Kubernetes versions ───────────────────────────────────────────────────────────

output "kubernetes_version" {
  description = "Actual Kubernetes version running on the cluster (from OCI, post-apply)."
  value       = oci_containerengine_cluster.arm_cluster.kubernetes_version
}

output "latest_available_kubernetes_version" {
  description = "Latest Kubernetes version available in this region (from OCI cluster options)."
  value       = local.latest_kubernetes_version
}

output "node_pool_kubernetes_version" {
  description = "Kubernetes version running on the node pool."
  value       = oci_containerengine_node_pool.arm_pool.kubernetes_version
}

# ── Networking ────────────────────────────────────────────────────────────────────

output "vcn_id" {
  description = "OCID of the VCN."
  value       = oci_core_vcn.vcn.id
}

output "cluster_region" {
  description = "OCI region of the cluster."
  value       = local.effective_region
}

# ── Node pool ─────────────────────────────────────────────────────────────────────

output "arm_node_pool_id" {
  description = "OCID of the ARM node pool."
  value       = oci_containerengine_node_pool.arm_pool.id
}

output "node_shape" {
  description = "Compute shape used by worker nodes."
  value       = oci_containerengine_node_pool.arm_pool.node_shape
}

output "node_image_name" {
  description = "OKE-prebuilt worker image selected for this cluster (auto-tracks latest build for the cluster K8s version)."
  value       = local.node_image_name
}

output "architecture" {
  description = "CPU architecture of the worker nodes."
  value       = "arm64"
}

# ── Monitoring ────────────────────────────────────────────────────────────────────

output "grafana_url" {
  description = "Grafana access URL (port-forward or LoadBalancer)."
  value       = module.monitoring.grafana_url
}

output "prometheus_url" {
  description = "Prometheus access URL (port-forward or LoadBalancer)."
  value       = module.monitoring.prometheus_url
}

output "grafana_admin_password" {
  description = "Grafana admin password (auto-generated if not supplied). Retrieve with: tofu output -raw grafana_admin_password"
  value       = local.effective_grafana_password
  sensitive   = true
}

# ── Resolved configuration ────────────────────────────────────────────────────

output "compartment_ocid_in_use" {
  description = "Compartment OCID actually used (resolved from var or ~/.oci/config)."
  value       = local.effective_compartment_ocid
}

output "region_in_use" {
  description = "OCI region actually used (resolved from var or ~/.oci/config)."
  value       = local.effective_region
}
