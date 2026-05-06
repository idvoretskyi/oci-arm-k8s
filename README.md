# OCI ARM Kubernetes Cluster (CNCF Demo)

[![Security Scan](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml/badge.svg)](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

OpenTofu configuration for a **$0/month** ARM-based OKE demo cluster on Oracle Cloud Infrastructure, sized for the Always Free tier, auto-upgrading to the latest Kubernetes version on each apply.

## Quick Start

Requires: OCI CLI configured (`~/.oci/config`), [OpenTofu](https://opentofu.org) 1.6+, `kubectl`.

```bash
cd tf
tofu init
tofu apply
```

That's it — no `-var` flags needed. Region, tenancy/compartment, and Grafana password are all resolved automatically (see [Authentication & defaults](#authentication--defaults) below).

Configure kubectl:
```bash
eval "$(tofu output -raw kubeconfig_command)"
kubectl get nodes -o wide
```

Retrieve the auto-generated Grafana password:
```bash
tofu output -raw grafana_admin_password
```

## What You Get

- **ARM node** — 1 × VM.Standard.A1.Flex (2 OCPU, 12 GB RAM), Always Free; OKE Basic cluster (free)
- **Network** — public subnet (API endpoint + LB) + private subnet (workers); NAT Gateway for internet egress (free on OCI); OCI Service Gateway for low-latency OCI Registry access
- **Auto-upgrade** — `kubernetes_version = null` (default) tracks latest OKE version in the region; pin or stage upgrades via variables
- **Monitoring** — kube-prometheus-stack (Grafana + Prometheus) + metrics-server, tuned for the single demo node
- **CIS baseline** — split security lists, `api_allowed_cidrs`, tagging, flow logs opt-in; see [`docs/cis-compliance.md`](docs/cis-compliance.md)

## Authentication & defaults

All values are auto-discovered from `~/.oci/config` (the same file used by the OCI CLI). Precedence for each value (highest wins):

| Source | How |
|--------|-----|
| Explicit `-var` flag or `TF_VAR_*` env var | `-var='region=us-ashburn-1'` |
| `terraform.tfvars` / `*.auto.tfvars` (gitignored) | `region = "us-ashburn-1"` |
| `~/.oci/config` profile (default: `DEFAULT`) | auto-read by OpenTofu |
| Error | friendly message if value cannot be resolved |

The profile used defaults to `DEFAULT`. Override with `-var='oci_profile=MYPROFILE'`.

**What is auto-discovered:**

| Value | Source |
|-------|--------|
| `region` | `region` key in `~/.oci/config` |
| `compartment_ocid` | `tenancy` key in `~/.oci/config` (= root compartment OCID) |
| `grafana_admin_password` | 24-char random password, generated once and stored in state |
| API credentials (user, fingerprint, key) | Read directly by the OCI provider from `~/.oci/config` |

To override any value, pass it as a variable:
```bash
tofu apply \
  -var='compartment_ocid=ocid1.compartment.oc1..xxx' \
  -var='region=us-ashburn-1' \
  -var='grafana_admin_password=mysecret'
```

Or create a gitignored `terraform.tfvars`:
```hcl
compartment_ocid       = "ocid1.compartment.oc1..xxx"
region                 = "us-ashburn-1"
grafana_admin_password = "mysecret"
```

## Configuration

Key variables (full list in [`tf/variables.tf`](tf/variables.tf)):

| Variable | Default | Description |
|----------|---------|-------------|
| `oci_profile` | `DEFAULT` | Profile name to read from `~/.oci/config` |
| `compartment_ocid` | `null` (from `~/.oci/config`) | OCI compartment OCID; defaults to root compartment |
| `region` | `null` (from `~/.oci/config`) | Deployment region |
| `kubernetes_version` | `null` (latest) | Pin with e.g. `"v1.31.1"`; null = auto-upgrade |
| `api_allowed_cidrs` | `["0.0.0.0/0"]` | Restrict API access to operator CIDRs (CIS K8s 5.4.2) |
| `enable_nat_gateway` | `true` | NAT gateway for private worker egress. **Free on OCI**. |
| `grafana_admin_password` | `null` (auto-generated) | Retrieve with `tofu output -raw grafana_admin_password` |

## Cost

Stays at **$0/month** on OCI Always Free. The NAT gateway has no hourly charge on OCI — only outbound data transfer applies, which is free up to 10 TB/month.

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
# open http://localhost:3000
# username: admin
# password: $(tofu output -raw grafana_admin_password)
```

## Troubleshooting

**ARM capacity limited**: OCI Always Free ARM capacity can be constrained. Retry later or try a different region (`us-ashburn-1` often has more capacity).

**Images not pulling**: Worker nodes use the NAT gateway for internet egress. If you disabled it (`enable_nat_gateway = false`), only OCI Registry is reachable via Service Gateway. Re-enable NAT or supply your own image mirror.

**Cluster not ready after apply**: The `oci` CLI is required for exec-based auth. Ensure it is installed and `~/.oci/config` is valid.

**region/compartment not resolved**: If `~/.oci/config` is missing or the profile doesn't exist, OpenTofu will print a clear error. Pass the values explicitly via `-var` or create a `terraform.tfvars`.

## Further Reading

- [`tf/README.md`](tf/README.md) — deep-dive on configuration and upgrade workflow
- [`docs/cis-compliance.md`](docs/cis-compliance.md) — CIS control mapping

## License

MIT — see [LICENSE](LICENSE).
