# ARM OKE Cluster — Configuration Reference

OpenTofu configuration for a single-node ARM OKE cluster on OCI, sized for the Always Free tier and tuned for CNCF demo use.

## File Structure

```
tf/
├── variables.tf     — All input variables
├── locals.tf        — Computed locals (versions, tags, names)
├── provider.tf      — OCI, Kubernetes, Helm providers
├── network.tf       — VCN, gateways, route tables, security lists, NSG, subnets
├── cluster.tf       — OKE cluster resource
├── node-pool.tf     — ARM node pool resource
├── metrics-server.tf — metrics-server Helm release
├── main.tf          — Monitoring module call
└── outputs.tf       — All outputs
```

## Quick Start

```bash
tofu init
tofu plan -var='compartment_ocid=ocid1.compartment.oc1..xxx' \
          -var='grafana_admin_password=changeme'
tofu apply -var='compartment_ocid=ocid1.compartment.oc1..xxx' \
           -var='grafana_admin_password=changeme'
```

Or create a `terraform.tfvars` (gitignored):
```hcl
compartment_ocid       = "ocid1.compartment.oc1..xxx"
grafana_admin_password = "changeme"
```

## Key Variables

```hcl
# Defaults — no changes needed for a basic demo
cluster_name   = "arm-oke-demo"
region         = "uk-london-1"
node_count     = 1
node_ocpus     = 2
node_memory_gb = 12

# K8s version: null = always latest, auto-upgrades on each apply
kubernetes_version             = null
node_pool_kubernetes_version   = null   # follows cluster by default

# CIS: restrict API to specific IPs (default open for demo)
api_allowed_cidrs = ["0.0.0.0/0"]

# Cost: enable NAT gateway for unrestricted internet egress (~$32/mo)
enable_nat_gateway = false

# CIS: enable VCN flow logs
enable_flow_logs = false
```

## Upgrading Kubernetes

Auto-upgrade is on by default. Every `tofu apply` checks the latest version
available in the region and upgrades if a newer version exists.

### Full upgrade (both cluster and node pool together)

```bash
tofu apply  # both cluster and node pool upgrade in sequence
```

### Staged upgrade (cluster first, node pool second)

```bash
# 1. Lock node pool at current version
tofu apply -var='node_pool_kubernetes_version=v1.30.1'

# 2. After cluster upgrade completes and validates, release the lock
tofu apply  # node pool now catches up
```

### Pin to a specific version

```bash
tofu apply -var='kubernetes_version=v1.31.1'
```

### Check available versions

```bash
tofu output latest_available_kubernetes_version
```

## Verify Cluster

```bash
# Get the kubeconfig command from outputs
eval "$(tofu output -raw kubeconfig_command)"

kubectl get nodes -o wide
kubectl top nodes
kubectl get pods -A
```

## Cleanup

```bash
tofu destroy -var='compartment_ocid=...' -var='grafana_admin_password=...'
```

## ARM Notes

- All images must support `linux/arm64`. Most upstream images are multi-arch.
- Java / JVM workloads run unchanged on ARM.
- Compiled Go / Rust binaries must be built for `GOARCH=arm64`.
- Node is pre-labeled `kubernetes.io/arch=arm64` for nodeSelector use.
