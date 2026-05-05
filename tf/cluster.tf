# ── Available K8s versions data source ──────────────────────────────────────────

data "oci_containerengine_cluster_option" "options" {
  cluster_option_id = "all"
  compartment_id    = var.compartment_ocid
}

# ── OKE Cluster ───────────────────────────────────────────────────────────────────
# Basic cluster type — free of charge (Enhanced ~$0.10/hr).
# kubernetes_version tracks latest by default (see locals.tf).
# PSP (PodSecurityPolicy) removed: deprecated in K8s 1.21, removed in K8s 1.25+.
# Use Pod Security Admission (built-in, no IaC required) or a policy engine
# (Kyverno / OPA Gatekeeper) for runtime enforcement.
# CKV2_OCI_6: checkov expects is_pod_security_policy_enabled=true, but PSP was
# removed from Kubernetes in v1.25. Setting it on modern OKE clusters causes an
# apply error. PSA (Pod Security Admission) is used instead — enforced at the
# namespace level via labels, not a cluster API flag.
#checkov:skip=CKV2_OCI_6:PSP removed in K8s 1.25+; Pod Security Admission enforced via namespace labels instead

resource "oci_containerengine_cluster" "arm_cluster" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = local.kubernetes_version
  name               = local.cluster_name
  vcn_id             = oci_core_vcn.vcn.id
  type               = "BASIC_CLUSTER"
  freeform_tags      = local.freeform_tags

  endpoint_config {
    # Public endpoint required for the demo; restrict access via api_allowed_cidrs.
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.public_subnet.id
    nsg_ids              = [oci_core_network_security_group.oke_cluster_nsg.id]
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.public_subnet.id]

    add_ons {
      is_kubernetes_dashboard_enabled = false # CIS 5.1.x
      is_tiller_enabled               = false # Helm 2 tiller — deprecated
    }

    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }
  }
}
