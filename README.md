# OCI ARM Kubernetes Cluster

[![Security Scan](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml/badge.svg)](https://github.com/idvoretskyi/oci-arm-k8s/actions/workflows/security-scan.yml)

Simple OpenTofu configuration for deploying an ARM-based OKE cluster on Oracle Cloud Infrastructure (OCI). Defaults target the London region and follow Oracle guidance: public subnet for API/LB and private subnet for worker nodes.

## Features

- ARM instances: VM.Standard.A1.Flex (ARM64)
- Automatic image selection: latest Oracle Linux 8 ARM image
- Minimal input: reads tenancy/user from ~/.oci/config by default
- Public API/LB + private worker subnets (recommended)
- Monitoring optional via kube-prometheus-stack (Grafana/Prometheus)
- London region by default (uk-london-1)

## Architecture

- Nodes: configurable; defaults to 2x ARM nodes (2 OCPUs, 8GB RAM each)
- Network: VCN with public subnet (API/LB) and private subnet (nodes) + NAT
- Security: minimal required rules (intra-VCN, API 6443, ICMP); tighten as needed

## Prerequisites

- OCI CLI configured (used for auth and kubeconfig token)
- OpenTofu 1.5+
- kubectl

## Quick Start

1. cd into Terraform directory
   ```bash
   cd tf
   ```

2. Optional: adjust variables in `terraform.tfvars` (defaults read tenancy/user from `~/.oci/config`)

3. Deploy
   ```bash
   tofu init
   tofu apply
   ```

4. Generate kubeconfig and verify
   ```bash
   # Get the command from outputs and run it
   tofu output kubeconfig_command
   # example output runs `oci ce cluster create-kubeconfig ...`
   kubectl get nodes -o wide
   ```

## Configuration

Common variables (`tf/variables.tf`):

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `uk-london-1` | Deployment region |
| `tenancy_ocid` | `null` | Read from `~/.oci/config` if null |
| `cluster_name` | `null` | Defaults to `{username}-arm-oke-cluster` if null |
| `kubernetes_version` | `null (auto-detect latest)` | Cluster version (null = latest supported) |
| `node_count` | `2` | Worker nodes count |
| `node_memory_gb` | `8` | Memory per node (GB) |
| `node_ocpus` | `2` | OCPUs per node |
| `grafana_admin_password` | `admin123!` | Change for production |

## Cost Optimization

ARM (A1.Flex) is very cost-efficient:
- Always Free eligible (up to 4 OCPUs, 24GB RAM)
- Significant savings vs. equivalent x86 shapes

## Monitoring

If monitoring is enabled, useful outputs are provided:
- `grafana_url`, `prometheus_url`, `monitoring_endpoints`
- Default Grafana username: `admin`; password from `grafana_admin_password`

## Troubleshooting

ARM capacity can be limited. Try:
- Reduce `node_count` (e.g., to 1)
- Retry later or choose another AD/region

Images are auto-selected for ARM (Oracle Linux 8). If unavailable, retry later.

## More docs

See `tf/README.md` for a deeper dive into architecture, configuration, and testing.

## License

MIT License - see [LICENSE](LICENSE) file.