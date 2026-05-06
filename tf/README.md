# ARM OKE Cluster — Configuration Reference

OpenTofu configuration for a single-node ARM OKE cluster on OCI, sized for the Always Free tier and tuned for CNCF demo use.

## File Structure

```
tf/
├── variables.tf      — All input variables
├── locals.tf         — OCI config discovery, computed locals, random password resource
├── provider.tf       — OCI, Kubernetes, Helm, Random providers
├── network.tf        — VCN, gateways, route tables, security lists, NSG, subnets
├── cluster.tf        — OKE cluster resource
├── node-pool.tf      — ARM node pool resource
├── metrics-server.tf — metrics-server Helm release
├── main.tf           — Monitoring module call
└── outputs.tf        — All outputs
```

## Quick Start

```bash
tofu init
tofu apply   # zero args — reads ~/.oci/config automatically
```

Retrieve the Grafana password after apply:
```bash
tofu output -raw grafana_admin_password
```

## OCI config auto-discovery

Values are resolved in this order (highest priority first):

1. Explicit `-var` flag or `TF_VAR_*` environment variable
2. `terraform.tfvars` / `*.auto.tfvars` (gitignored)
3. `~/.oci/config` — profile specified by `var.oci_profile` (default: `DEFAULT`)
4. Error with a descriptive message

| Value | Auto-source |
|-------|-------------|
| `region` | `region` key in the config profile |
| `compartment_ocid` | `tenancy` key (root compartment OCID) |
| `grafana_admin_password` | 24-char random password, stable across applies |
| API credentials | Read by the OCI provider natively from `~/.oci/config` |

To use a non-default profile:
```bash
tofu apply -var='oci_profile=MYPROFILE'
```

To override individual values:
```hcl
# terraform.tfvars (gitignored)
compartment_ocid       = "ocid1.compartment.oc1..xxx"
region                 = "us-ashburn-1"
grafana_admin_password = "mysecret"
```

## Key Variables

```hcl
# OCI config profile (default: reads [DEFAULT] from ~/.oci/config)
oci_profile = "DEFAULT"

# Region and compartment: null = auto-discovered from ~/.oci/config
region           = null
compartment_ocid = null

# Cluster defaults — no changes needed for a basic demo
cluster_name   = "arm-oke-demo"
node_count     = 1
node_ocpus     = 2
node_memory_gb = 12

# K8s version: null = always latest, auto-upgrades on each apply
kubernetes_version           = null
node_pool_kubernetes_version = null   # follows cluster by default

# CIS: restrict API to specific IPs (default open for demo)
api_allowed_cidrs = ["0.0.0.0/0"]

# NAT gateway: free on OCI (no hourly charge); enabled by default for outbound egress
enable_nat_gateway = true

# CIS: enable VCN flow logs
enable_flow_logs = false

# Grafana password: null = auto-generated; retrieve with: tofu output -raw grafana_admin_password
grafana_admin_password = null
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
# Configure kubectl from outputs
eval "$(tofu output -raw kubeconfig_command)"

kubectl get nodes -o wide
kubectl top nodes
kubectl get pods -A
```

## Cleanup

```bash
tofu destroy
```

## ARM Notes

- Worker nodes use OKE-prebuilt Oracle Linux 8.10 aarch64 images. These ship with
  kubelet, containerd, and OCI agents preinstalled and version-locked to the control
  plane. Oracle Linux 8.10 is the only OKE-blessed ARM64 worker OS; OL9/OL10/Ubuntu
  aarch64 images exist in OCI but are not offered as OKE-prebuilt worker images.
  The latest available build for the cluster K8s version is selected automatically.
- All container images must support `linux/arm64`. Most upstream images are multi-arch.
- Java / JVM workloads run unchanged on ARM.
- Compiled Go / Rust binaries must be built for `GOARCH=arm64`.
- Node is pre-labeled `kubernetes.io/arch=arm64` for nodeSelector use.
