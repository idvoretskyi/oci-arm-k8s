# Monitoring Module for OKE

Deploys [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) (Grafana + Prometheus + Node Exporter + kube-state-metrics) onto an OKE ARM cluster.

Tuned for a single ARM A1.Flex demo node (2 OCPU / 12 GB RAM) within the OCI Always Free tier.

## Features

- **Prometheus** — metrics collection with persistent OCI Block Volume storage
- **Grafana** — pre-configured dashboards with persistent storage
- **Node Exporter** — host-level metrics
- **Kube State Metrics** — Kubernetes object metrics
- **Alertmanager** — disabled by default (saves ~150 MB RAM on demo node)
- **ARM64** — all components scheduled on ARM nodes via global nodeSelector

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  create_storage_class   = true
  storage_class          = "oci-bv-paravirtualized"
  grafana_admin_password = var.grafana_admin_password
}
```

## Requirements

| Name | Version |
|------|---------|
| opentofu | >= 1.6.0 |
| kubernetes | >= 3.0.1 |
| helm | >= 3.1.1 |

## Providers

| Name | Version |
|------|---------|
| helm | >= 3.1.1 |
| kubernetes | >= 3.0.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| grafana_admin_password | Grafana admin password | `string` | n/a | yes |
| monitoring_namespace | Kubernetes namespace | `string` | `"monitoring"` | no |
| chart_version | kube-prometheus-stack chart version | `string` | `"65.8.1"` | no |
| storage_class | Storage class for PVs | `string` | `"oci-bv-paravirtualized"` | no |
| prometheus_storage_size | Prometheus PV size | `string` | `"50Gi"` | no |
| prometheus_retention | Prometheus retention period | `string` | `"3d"` | no |
| grafana_storage_size | Grafana PV size | `string` | `"50Gi"` | no |
| grafana_service_type | Grafana service type | `string` | `"ClusterIP"` | no |
| grafana_ingress_enabled | Enable Grafana ingress | `bool` | `false` | no |
| node_exporter_enabled | Enable node-exporter | `bool` | `true` | no |
| kube_state_metrics_enabled | Enable kube-state-metrics | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| monitoring_namespace | Namespace of monitoring components |
| grafana_url | URL to access Grafana |
| prometheus_url | URL to access Prometheus |
| grafana_service_name | Grafana Kubernetes service name |
| prometheus_service_name | Prometheus Kubernetes service name |
| monitoring_endpoints | Cluster-local service endpoints (grafana_service, prometheus_service) |

## Accessing Services (demo defaults — ClusterIP)

```bash
# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-kube-prom-prometheus 9090:9090
```

Login: `admin` / `<grafana_admin_password>`

## Resource footprint (demo node: 2 OCPU / 12 GB)

| Component | CPU req | Memory req |
|-----------|---------|------------|
| Prometheus | 100m | 512Mi |
| Grafana | 50m | 128Mi |
| Prometheus Operator | 50m | 128Mi |
| Node Exporter | 20m | 32Mi |
| Kube State Metrics | 20m | 64Mi |
| **Total** | **~240m** | **~864Mi** |

This leaves ~11 GB for demo workloads on the 12 GB node.
