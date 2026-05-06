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

Get the Grafana password:
```bash
tofu output -raw grafana_admin_password
```

Tear down:
```bash
tofu destroy
```

## OCI config auto-discovery

Values are resolved in this order (highest priority first):

1. Explicit `-var` flag or `TF_VAR_*` environment variable
2. `terraform.tfvars` / `*.auto.tfvars` (gitignored)
3. `~/.oci/config` — profile set by `oci_profile` variable (default: `DEFAULT`)
4. Error with a descriptive message

| Value | Auto-source |
|-------|-------------|
| `region` | `region` key in the config profile |
| `compartment_ocid` | `tenancy` key (= root compartment OCID) |
| `grafana_admin_password` | 24-char random password, stable across applies |
| API credentials (user, fingerprint, key) | Read natively by the OCI provider |

Use a non-default profile:
```bash
tofu apply -var='oci_profile=MYPROFILE'
```

Override individual values via `terraform.tfvars` (gitignored):
```hcl
compartment_ocid       = "ocid1.compartment.oc1..xxx"
region                 = "us-ashburn-1"
grafana_admin_password = "mysecret"
```

## Key Variables

Full list in [`variables.tf`](variables.tf). Common overrides:

```hcl
# OCI profile (default: [DEFAULT] in ~/.oci/config)
oci_profile = "DEFAULT"

# Region and compartment: null = auto-discovered from ~/.oci/config
region           = null
compartment_ocid = null

# Cluster
cluster_name   = "arm-oke-demo"
node_count     = 1
node_ocpus     = 2
node_memory_gb = 12

# Kubernetes version: null = always latest, auto-upgrades on each apply
kubernetes_version           = null
node_pool_kubernetes_version = null   # follows cluster by default

# CIS: restrict API server access (default open for demo)
api_allowed_cidrs = ["0.0.0.0/0"]

# NAT gateway: free on OCI; required for DockerHub/GitHub image pulls
enable_nat_gateway = true

# VCN flow logs (CIS OCI 4.x — minor log-storage cost)
enable_flow_logs = false

# Grafana password: null = auto-generated
grafana_admin_password = null
```

## Upgrading Kubernetes

Auto-upgrade is on by default — every `tofu apply` upgrades if OCI has published a newer version.

Check what is available:
```bash
tofu output latest_available_kubernetes_version
```

### Full upgrade (cluster + node pool together)

```bash
tofu apply
```

### Staged upgrade (cluster first, node pool after validation)

```bash
# 1. Lock node pool at its current version while cluster upgrades
tofu apply -var='node_pool_kubernetes_version=v1.34.2'

# 2. After the cluster upgrade validates, release the lock
tofu apply
```

### Pin to a specific version

```bash
tofu apply -var='kubernetes_version=v1.35.2'
```

> Version examples use values current at time of writing. Check `tofu output latest_available_kubernetes_version` to see what your region offers today.

## Verify Cluster

```bash
eval "$(tofu output -raw kubeconfig_command)"
kubectl get nodes -o wide
kubectl top nodes
kubectl get pods -A
```

## Monitoring

Deployed via [`modules/monitoring`](../modules/monitoring/README.md) — kube-prometheus-stack (Grafana + Prometheus + Node Exporter + kube-state-metrics), tuned for the single ARM demo node.

```bash
# Grafana — http://localhost:3000  admin / $(tofu output -raw grafana_admin_password)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus — http://localhost:9090
kubectl port-forward -n monitoring svc/kube-prometheus-stack-kube-prom-prometheus 9090:9090
```

## ARM Notes

- Worker nodes use OKE-prebuilt Oracle Linux 8.10 aarch64 images — kubelet, containerd, and OCI agents are preinstalled and version-locked to the control plane. OL 8.10 is the only OKE-blessed ARM64 worker OS today; OL9/OL10/Ubuntu aarch64 exist in OCI but are not offered as OKE-prebuilt images. The latest build for the cluster K8s version is selected automatically.
- All container images must support `linux/arm64`. Most upstream images are multi-arch.
- Java / JVM workloads run unchanged on ARM.
- Go / Rust binaries must target `GOARCH=arm64`.
- Nodes are pre-labeled `kubernetes.io/arch=arm64` for `nodeSelector` use.
