# ── Authentication & tenancy ────────────────────────────────────────────────────
# The OCI provider reads ~/.oci/config automatically when these are left null.
# Override only when running in CI or multi-tenancy setups.

variable "region" {
  description = "OCI region for the cluster."
  type        = string
  default     = "uk-london-1"
}

variable "compartment_ocid" {
  description = "OCID of the compartment to deploy into. Required."
  type        = string
}

variable "fingerprint" {
  description = "API key fingerprint. Leave null to use ~/.oci/config."
  type        = string
  default     = null
}

variable "private_key_path" {
  description = "Path to the OCI API private key. Leave null to use ~/.oci/config."
  type        = string
  default     = null
}

# ── Cluster ─────────────────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "Display name for the OKE cluster. Defaults to 'arm-oke-demo'."
  type        = string
  default     = "arm-oke-demo"
}

variable "kubernetes_version" {
  description = <<-EOT
    Kubernetes version for the OKE cluster.
    Set to null (default) to always use the latest version available in the region.
    Each `tofu apply` will upgrade the cluster when OCI publishes a new version.
    Pin to a specific value (e.g. "v1.31.1") to freeze the version.
  EOT
  type        = string
  default     = null
}

variable "node_pool_kubernetes_version" {
  description = <<-EOT
    Kubernetes version for the node pool.
    Defaults to null, which tracks the cluster version.
    Set explicitly to lag behind the cluster during a staged upgrade:
      1. Apply with cluster at vX.Y — node pool follows.
      2. Set this to vX.(Y-1) before bumping the cluster to vX.(Y+1).
  EOT
  type        = string
  default     = null
}

# ── Node pool ───────────────────────────────────────────────────────────────────

variable "node_count" {
  description = "Number of worker nodes. 1 is sufficient for a demo and fits within the OCI Always Free ARM allotment."
  type        = number
  default     = 1
}

variable "node_ocpus" {
  description = "OCPUs per node (ARM A1.Flex). Always Free = up to 4 total."
  type        = number
  default     = 2
}

variable "node_memory_gb" {
  description = "Memory (GB) per node (ARM A1.Flex). Always Free = up to 24 GB total."
  type        = number
  default     = 12
}

# ── Networking ──────────────────────────────────────────────────────────────────

variable "api_allowed_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach the Kubernetes API server (port 6443).
    Defaults to open (0.0.0.0/0) for demo convenience.
    CIS K8s 5.4.2: narrow this to operator IP ranges in production.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_nat_gateway" {
  description = <<-EOT
    When false (default) worker nodes use an OCI Service Gateway for outbound
    traffic — free, reaches OCI services and the OCI container registry.
    Set to true to add a NAT gateway (~$32/month) for unrestricted internet egress
    (e.g. pulling images from DockerHub or GitHub).
  EOT
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VCN flow logs on public and private subnets (CIS OCI 4.x). Incurs minor log-storage cost."
  type        = bool
  default     = false
}

# ── Monitoring ──────────────────────────────────────────────────────────────────

variable "grafana_admin_password" {
  description = "Admin password for Grafana. Must be set — no default for security reasons."
  type        = string
  sensitive   = true
}
