# OCI ARM Kubernetes Cluster (CNCF Demo)

[![Security Scan](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml/badge.svg)](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A `$0/month` reference cluster on OCI Always Free for CNCF demos and ARM64 experimentation. One `tofu apply` — no flags, no manual config — gives you a single-node ARM OKE cluster with Prometheus and Grafana, auto-upgrading to the latest Kubernetes version. Not intended for production.

## Quick Start

**Prerequisites:** [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) configured (`~/.oci/config`), [OpenTofu](https://opentofu.org) 1.6+, `kubectl`.

```bash
cd tf
tofu init
tofu apply
```

Region, compartment, and Grafana password are all resolved from `~/.oci/config` — no `-var` flags needed. See [`tf/README.md`](tf/README.md) for override options.

Configure kubectl:
```bash
eval "$(tofu output -raw kubeconfig_command)"
kubectl get nodes -o wide
```

Get the Grafana password:
```bash
tofu output -raw grafana_admin_password
```

## What You Get

- **ARM node** — 1 × VM.Standard.A1.Flex (2 OCPU, 12 GB RAM), Always Free; OKE Basic cluster (free)
- **Network** — public subnet (API + LB) + private subnet (workers); NAT Gateway (free on OCI); OCI Service Gateway for registry access
- **Auto-upgrade** — tracks the latest OKE version in the region on every `tofu apply`
- **Monitoring** — kube-prometheus-stack (Grafana + Prometheus) + metrics-server, tuned for the demo node
- **CIS baseline** — split security lists, `api_allowed_cidrs`, resource tagging; see [`docs/cis-compliance.md`](docs/cis-compliance.md)

## Cost

**$0/month** on OCI Always Free. The NAT gateway has no hourly charge — only outbound data transfer applies, free up to 10 TB/month.

## Monitoring

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000  admin / $(tofu output -raw grafana_admin_password)
```

## Troubleshooting

- **ARM capacity unavailable** — OCI Always Free ARM quota can be constrained; retry later or switch region (`us-ashburn-1` usually has more capacity).
- **Images not pulling** — NAT gateway is required for DockerHub/GitHub pulls; ensure `enable_nat_gateway = true` (the default).
- **kubectl auth fails** — the `oci` CLI must be installed and `~/.oci/config` must be valid; exec-based token generation depends on it.
- **region/compartment not resolved** — if `~/.oci/config` is missing or malformed, OpenTofu prints a clear error; pass values via `-var` or `terraform.tfvars`.

## Further Reading

- [`tf/README.md`](tf/README.md) — configuration reference, variable overrides, upgrade workflow
- [`modules/monitoring/README.md`](modules/monitoring/README.md) — monitoring module API
- [`docs/cis-compliance.md`](docs/cis-compliance.md) — CIS control mapping

## License

MIT — see [LICENSE](LICENSE).
