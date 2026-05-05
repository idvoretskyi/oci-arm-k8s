terraform {
  required_version = ">= 1.6.0" # OpenTofu 1.6+ required

  required_providers {
    oci = {
      source  = "registry.opentofu.org/oracle/oci"
      version = ">= 8.0.0"
    }
    # OpenTofu mirrors the hashicorp/ namespace via registry.opentofu.org.
    # Explicit opentofu/ namespace sources are used where available.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
    }
  }
}

# ── OCI provider ────────────────────────────────────────────────────────────────
# Reads tenancy/user/region from ~/.oci/config automatically when fingerprint
# and private_key_path are null (the default). Override via variables for CI.
provider "oci" {
  region           = var.region
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

# ── Cluster kubeconfig ──────────────────────────────────────────────────────────
# Derived from OCI so no chicken-and-egg dependency on ~/.kube/config.
# The exec block calls the OCI CLI to generate a short-lived token — the same
# mechanism used by `oci ce cluster create-kubeconfig`.
# Prerequisite: the `oci` CLI must be installed and configured.
data "oci_containerengine_cluster_kube_config" "kc" {
  cluster_id    = oci_containerengine_cluster.arm_cluster.id
  token_version = "2.0.0"
}

locals {
  kube_config_raw = yamldecode(data.oci_containerengine_cluster_kube_config.kc.content)
  kube_host       = local.kube_config_raw["clusters"][0]["cluster"]["server"]
  kube_ca_cert    = base64decode(local.kube_config_raw["clusters"][0]["cluster"]["certificate-authority-data"])
}

# ── Kubernetes provider ─────────────────────────────────────────────────────────
provider "kubernetes" {
  host                   = local.kube_host
  cluster_ca_certificate = local.kube_ca_cert

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "oci"
    args = [
      "ce", "cluster", "generate-token",
      "--cluster-id", oci_containerengine_cluster.arm_cluster.id,
      "--region", var.region
    ]
  }
}

# ── Helm provider ───────────────────────────────────────────────────────────────
provider "helm" {
  kubernetes = {
    host                   = local.kube_host
    cluster_ca_certificate = local.kube_ca_cert

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "oci"
      args = [
        "ce", "cluster", "generate-token",
        "--cluster-id", oci_containerengine_cluster.arm_cluster.id,
        "--region", var.region
      ]
    }
  }
}
