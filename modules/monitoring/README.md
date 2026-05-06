# Monitoring Module

Deploys [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) (Grafana + Prometheus + Node Exporter + kube-state-metrics) onto an OKE ARM cluster.

Tuned for a single ARM A1.Flex demo node (2 OCPU / 12 GB RAM) within the OCI Always Free tier.

## Features

- **Prometheus** — metrics collection with persistent OCI Block Volume storage
- **Grafana** — pre-configured dashboards with persistent storage
- **Node Exporter** — host-level metrics
- **Kube State Metrics** — Kubernetes object metrics
- **Alertmanager** — disabled by default (saves ~150 MB RAM on the demo node)
- **ARM64** — all components scheduled on ARM nodes via global `nodeSelector`

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  create_storage_class   = true
  storage_class          = "oci-bv-paravirtualized"
  grafana_admin_password = local.effective_grafana_password  # auto-generated when null
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
| `grafana_admin_password` | Grafana admin password | `string` | n/a | yes |
| `monitoring_namespace` | Kubernetes namespace | `string` | `"monitoring"` | no |
| `release_name` | Helm release name | `string` | `"kube-prometheus-stack"` | no |
| `chart_version` | kube-prometheus-stack chart version | `string` | `"65.8.1"` | no |
| `helm_timeout` | Helm install/upgrade timeout (seconds) | `number` | `900` | no |
| `storage_class` | Storage class for PVs | `string` | `"oci-bv-paravirtualized"` | no |
| `create_storage_class` | Create the OCI Block Volume storage class | `bool` | `false` | no |
| `prometheus_storage_size` | Prometheus PV size | `string` | `"50Gi"` | no |
| `prometheus_retention` | Prometheus retention period | `string` | `"3d"` | no |
| `prometheus_retention_size` | Prometheus retention size limit | `string` | `"8GiB"` | no |
| `grafana_storage_size` | Grafana PV size | `string` | `"50Gi"` | no |
| `grafana_persistence_enabled` | Enable Grafana persistent storage | `bool` | `true` | no |
| `grafana_service_type` | Grafana service type (`ClusterIP`, `NodePort`, `LoadBalancer`) | `string` | `"ClusterIP"` | no |
| `grafana_ingress_enabled` | Enable Grafana ingress | `bool` | `false` | no |
| `grafana_hostname` | Grafana ingress hostname | `string` | `"grafana.example.com"` | no |
| `grafana_ingress_annotations` | Grafana ingress annotations | `map(string)` | `{}` | no |
| `grafana_ingress_tls_enabled` | Enable TLS on Grafana ingress | `bool` | `false` | no |
| `prometheus_ingress_enabled` | Enable Prometheus ingress | `bool` | `false` | no |
| `prometheus_hostname` | Prometheus ingress hostname | `string` | `"prometheus.example.com"` | no |
| `prometheus_ingress_annotations` | Prometheus ingress annotations | `map(string)` | `{}` | no |
| `prometheus_ingress_tls_enabled` | Enable TLS on Prometheus ingress | `bool` | `false` | no |
| `ingress_class` | Ingress class name | `string` | `"nginx"` | no |
| `node_exporter_enabled` | Enable node-exporter | `bool` | `true` | no |
| `kube_state_metrics_enabled` | Enable kube-state-metrics | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| `monitoring_namespace` | Namespace of monitoring components |
| `helm_release_name` | Helm release name |
| `helm_release_version` | Deployed chart version |
| `helm_release_status` | Helm release status |
| `grafana_url` | Grafana access command or ingress URL |
| `prometheus_url` | Prometheus access command or ingress URL |
| `grafana_service_name` | Grafana Kubernetes service name |
| `prometheus_service_name` | Prometheus Kubernetes service name |
| `grafana_admin_password` | Grafana admin password (sensitive) |
| `grafana_ingress_hostname` | Grafana ingress hostname (null if ingress disabled) |
| `prometheus_ingress_hostname` | Prometheus ingress hostname (null if ingress disabled) |
| `storage_class` | Storage class in use |
| `monitoring_endpoints` | Cluster-local service FQDNs (`grafana_service`, `prometheus_service`) |

## Accessing Services (demo defaults — ClusterIP)

```bash
# Grafana — http://localhost:3000
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus — http://localhost:9090
kubectl port-forward -n monitoring svc/kube-prometheus-stack-kube-prom-prometheus 9090:9090
```

Login: `admin` / `<grafana_admin_password>`

## Resource Footprint (demo node: 2 OCPU / 12 GB)

| Component | CPU req | Memory req |
|-----------|---------|------------|
| Prometheus | 100m | 512Mi |
| Grafana | 50m | 128Mi |
| Prometheus Operator | 50m | 128Mi |
| Node Exporter | 20m | 32Mi |
| Kube State Metrics | 20m | 64Mi |
| **Total** | **~240m** | **~864Mi** |

Leaves ~11 GB for demo workloads on the 12 GB node.
