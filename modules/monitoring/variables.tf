variable "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring components."
  type        = string
  default     = "monitoring"
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.monitoring_namespace))
    error_message = "monitoring_namespace must be a valid Kubernetes namespace name."
  }
}

variable "release_name" {
  description = "Helm release name for the kube-prometheus-stack."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "chart_version" {
  description = "kube-prometheus-stack Helm chart version. Tested on K8s 1.35; chart 65.x supports K8s 1.25+."
  type        = string
  default     = "65.8.1"
}

variable "helm_timeout" {
  description = "Helm install/upgrade timeout in seconds."
  type        = number
  default     = 900
}

variable "storage_class" {
  description = "Storage class for persistent volumes."
  type        = string
  default     = "oci-bv-paravirtualized"
}

variable "create_storage_class" {
  description = "Whether to create the OCI Block Volume storage class."
  type        = bool
  default     = false
}

# Demo-tuned storage defaults — fits within OCI Always Free 200 GB block storage limit.
variable "prometheus_storage_size" {
  description = "Persistent volume size for Prometheus data."
  type        = string
  default     = "50Gi"
}

variable "prometheus_retention" {
  description = "Prometheus data retention period."
  type        = string
  default     = "3d"
}

variable "prometheus_retention_size" {
  description = "Prometheus data retention size limit."
  type        = string
  default     = "8GiB"
}

variable "grafana_storage_size" {
  description = "Persistent volume size for Grafana."
  type        = string
  default     = "50Gi"
}

variable "grafana_persistence_enabled" {
  description = "Enable Grafana persistent storage."
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Required — no default for security reasons."
  type        = string
  sensitive   = true
}

variable "grafana_service_type" {
  description = "Kubernetes service type for Grafana."
  type        = string
  default     = "ClusterIP"
  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.grafana_service_type)
    error_message = "grafana_service_type must be one of: ClusterIP, NodePort, LoadBalancer."
  }
}

variable "grafana_ingress_enabled" {
  type    = bool
  default = false
}

variable "grafana_hostname" {
  type    = string
  default = "grafana.example.com"
}

variable "grafana_ingress_annotations" {
  type    = map(string)
  default = {}
}

variable "grafana_ingress_tls_enabled" {
  type    = bool
  default = false
}

variable "prometheus_ingress_enabled" {
  type    = bool
  default = false
}

variable "prometheus_hostname" {
  type    = string
  default = "prometheus.example.com"
}

variable "prometheus_ingress_annotations" {
  type    = map(string)
  default = {}
}

variable "prometheus_ingress_tls_enabled" {
  type    = bool
  default = false
}

variable "ingress_class" {
  type    = string
  default = "nginx"
}

variable "node_exporter_enabled" {
  description = "Enable node-exporter for host-level metrics."
  type        = bool
  default     = true
}

variable "kube_state_metrics_enabled" {
  description = "Enable kube-state-metrics for Kubernetes object metrics."
  type        = bool
  default     = true
}
