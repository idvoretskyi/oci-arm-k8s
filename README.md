# OCI ARM Kubernetes Cluster (CNCF Demo)

[![Security Scan](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml/badge.svg)](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

OpenTofu configuration for a **$0/month** ARM-based OKE demo cluster on Oracle Cloud Infrastructure, sized for the Always Free tier, auto-upgrading to the latest Kubernetes version on each apply.

## Quick Start

Requires: OCI CLI configured (`~/.oci/config`), [OpenTofu](https://opentofu.org) 1.6+, `kubectl`.

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

## What You Get

- **ARM node** — 1 × VM.Standard.A1.Flex (2 OCPU, 12 GB RAM), Always Free; OKE Basic cluster (free)
- **Network** — public subnet (API endpoint + LB) + private subnet (workers); OCI Service Gateway for free OCI Registry egress; optional NAT Gateway via variable
- **Auto-upgrade** — `kubernetes_version = null` (default) tracks latest OKE version in the region; pin or stage upgrades via variables
- **Monitoring** — kube-prometheus-stack (Grafana + Prometheus) + metrics-server, tuned for the single demo node
- **CIS baseline** — split security lists, `api_allowed_cidrs`, tagging, flow logs opt-in; see [`docs/cis-compliance.md`](docs/cis-compliance.md)

## Configuration

Key variables (full list in [`tf/variables.tf`](tf/variables.tf)):

| Variable | Default | Description |
|----------|---------|-------------|
| `compartment_ocid` | **required** | OCI compartment OCID |
| `region` | `uk-london-1` | Deployment region |
| `kubernetes_version` | `null` (latest) | Pin with e.g. `"v1.31.1"`; null = auto-upgrade |
| `api_allowed_cidrs` | `["0.0.0.0/0"]` | Restrict API access to operator CIDRs (CIS K8s 5.4.2) |
| `enable_nat_gateway` | `false` | Enable NAT gateway (~$32/mo) for unrestricted internet egress |
| `grafana_admin_password` | **required** | Grafana admin password |

## Cost

Stays at **$0/month** on OCI Always Free. Enabling `enable_nat_gateway = true` adds ~$32/mo.

## Upgrading Kubernetes

By default every `tofu apply` upgrades to the latest available version. To stage the upgrade (cluster first, node pool after validation):

```hcl
# Step 1 — pin node pool while cluster upgrades
node_pool_kubernetes_version = "v1.30.1"

# Step 2 — once validated, remove the pin and re-apply
node_pool_kubernetes_version = null
```

Check what version is available:
```bash
tofu output latest_available_kubernetes_version
```

## Monitoring

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000  (admin / <grafana_admin_password>)
```

## Troubleshooting

**ARM capacity limited**: OCI Always Free ARM capacity can be constrained. Retry later or try a different region (`us-ashburn-1` often has more capacity).

**Images not pulling**: Only OCI Registry is reachable by default via Service Gateway. For DockerHub/GHCR images set `enable_nat_gateway = true`.

**Cluster not ready after apply**: The `oci` CLI is required for exec-based auth. Ensure it is installed and `~/.oci/config` is valid.

## Further Reading

- [`tf/README.md`](tf/README.md) — deep-dive on configuration and upgrade workflow
- [`docs/cis-compliance.md`](docs/cis-compliance.md) — CIS control mapping

## License

MIT — see [LICENSE](LICENSE).
