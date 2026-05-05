# OCI ARM Kubernetes Cluster (CNCF Demo)

[![Security Scan](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml/badge.svg)](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml)

OpenTofu configuration for a **$0/month** ARM-based OKE demo cluster on Oracle Cloud Infrastructure. Targets the OCI Always Free tier, auto-upgrades to the latest Kubernetes version on each apply, and implements a CIS Kubernetes/OCI baseline.

## Features

- **ARM instances** — VM.Standard.A1.Flex (ARM64), always-free tier
- **Auto-upgrade K8s** — always tracks the latest OKE version; no manual version pinning required
- **$0/month** — sized for OCI Always Free (2 OCPU, 12 GB RAM, service gateway only)
- **CIS baseline** — split security lists, restricted API access variable, PSP removed, resource tagging
- **OpenTofu** — OpenTofu-native; no Terraform required
- **Monitoring** — kube-prometheus-stack (Grafana + Prometheus), tuned for the demo node
- **Metrics server** — deployed via Helm for idempotency
- **No NAT gateway** — OCI Service Gateway handles OCI registry pulls for free; enable NAT via variable if DockerHub/GitHub egress is needed

## Architecture

```
VCN (10.0.0.0/16)
├── public subnet (10.0.1.0/24)  — API endpoint, LB
│     └── security: api_allowed_cidrs on 6443, intra-VCN
└── private subnet (10.0.2.0/24) — ARM worker nodes
      └── security: intra-VCN only (no direct API exposure)

Egress: OCI Service Gateway (free) → OCI Registry / Object Storage
        Optional NAT Gateway ($32/mo) for unrestricted internet
```

- **Node**: 1 × VM.Standard.A1.Flex — 2 OCPU, 12 GB RAM (Always Free)
- **Kubernetes**: latest available version (auto-upgraded)
- **OKE type**: Basic cluster (free; Enhanced costs ~$0.10/hr)

## Prerequisites

- OCI CLI configured (`~/.oci/config`) — used for auth and kubeconfig tokens
- [OpenTofu](https://opentofu.org) 1.6+
- `kubectl`

## Quick Start

```bash
cd tf
tofu init
tofu apply -var='compartment_ocid=<your-compartment-ocid>' \
           -var='grafana_admin_password=<your-password>'
```

Configure kubectl:
```bash
tofu output kubeconfig_command  # prints the oci ce cluster create-kubeconfig command
# run the printed command, then:
kubectl get nodes -o wide
```

## Configuration

All variables in `tf/variables.tf`. Key ones:

| Variable | Default | Description |
|----------|---------|-------------|
| `compartment_ocid` | **required** | OCI compartment OCID |
| `region` | `uk-london-1` | Deployment region |
| `cluster_name` | `arm-oke-demo` | Cluster display name |
| `kubernetes_version` | `null` (latest) | Pin with e.g. `"v1.31.1"`; null = auto-upgrade |
| `node_pool_kubernetes_version` | `null` (follows cluster) | Lag node pool during staged upgrades |
| `node_count` | `1` | Worker nodes (1 fits Always Free) |
| `node_ocpus` | `2` | OCPUs per node |
| `node_memory_gb` | `12` | Memory GB per node |
| `api_allowed_cidrs` | `["0.0.0.0/0"]` | CIS K8s 5.4.2: restrict to operator CIDRs |
| `enable_nat_gateway` | `false` | Enable NAT gateway (~$32/mo) for internet egress |
| `enable_flow_logs` | `false` | VCN flow logs (CIS OCI 4.x) |
| `grafana_admin_password` | **required** | Grafana admin password |

## Cost

This configuration is designed to stay at **$0/month**:

| Resource | Cost |
|----------|------|
| VM.Standard.A1.Flex 2 OCPU / 12 GB | $0 (Always Free) |
| OKE Basic cluster | $0 |
| VCN + Service Gateway | $0 |
| NAT Gateway (default: disabled) | $0 (enable = ~$32/mo) |
| 50 GB boot volume | $0 (Free tier includes 200 GB) |
| Monitoring PVs (~14 GB total) | $0 (within free tier) |
| **Total** | **$0** |

To add unrestricted internet egress for pods (e.g. DockerHub):
```hcl
enable_nat_gateway = true  # adds ~$32/month
```

## Upgrading Kubernetes

By default (`kubernetes_version = null`), every `tofu apply` upgrades both the cluster and node pool to the latest available version in the region.

**Staged upgrade** (upgrade cluster first, validate, then node pool):
```hcl
# Step 1: apply with node pool lagging
node_pool_kubernetes_version = "v1.30.1"  # keep node pool here

# Step 2: after cluster upgrade validates, remove the override
node_pool_kubernetes_version = null  # now node pool catches up
```

**Pin a specific version** (freeze upgrades):
```hcl
kubernetes_version = "v1.31.1"
```

**Check what version is available**:
```bash
tofu output latest_available_kubernetes_version
```

## CIS Compliance

See [`docs/cis-compliance.md`](docs/cis-compliance.md) for a full control mapping.

Summary of what this configuration addresses:

- **CIS K8s 5.1.x** — Kubernetes Dashboard and Tiller disabled
- **CIS K8s 5.4.2** — API server access restricted via `api_allowed_cidrs`
- **CIS K8s** — PSP removed (deprecated/removed in K8s 1.25+); use Pod Security Admission or Kyverno
- **CIS OCI Net** — Split security lists (public/private); private workers not reachable on API port
- **CIS OCI 4.x** — VCN flow logs available via `enable_flow_logs = true`
- **Encryption** — PV encryption in transit enabled; OCI boot volumes encrypted at rest by default
- **Tagging** — All resources tagged with `ManagedBy=OpenTofu`, `Purpose=CNCF-demo`, `Environment=demo`

## Monitoring

kube-prometheus-stack is deployed by default. Access Grafana via port-forward:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000  (admin / <grafana_admin_password>)
```

## Troubleshooting

**ARM capacity limited**: OCI Always Free ARM capacity can be constrained. Retry later or try a different region (`us-ashburn-1` often has more capacity).

**Images not pulling**: By default only OCI Registry is reachable via Service Gateway. For DockerHub/GHCR images, set `enable_nat_gateway = true`.

**Cluster not ready after apply**: The `oci` CLI is required for the kubernetes/helm providers (exec-based auth). Ensure `oci` is installed and `~/.oci/config` is valid.

## More docs

- `tf/README.md` — deep-dive on configuration and upgrade workflow
- `docs/cis-compliance.md` — CIS control mapping

## License

MIT — see [LICENSE](LICENSE).
