# ── Data sources ──────────────────────────────────────────────────────────────────

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# OKE-prebuilt worker images for this cluster.
# These images ship with kubelet, kube-proxy, containerd, and OCI agents
# preinstalled and version-locked to the control plane. Oracle Linux 8.10
# is the only OKE-blessed ARM64 OS family; OL9/OL10/Ubuntu aarch64 platform
# images exist in OCI but are not shipped as OKE-prebuilt worker images.
# The filter picks ARM64 + OL8 + matching cluster K8s version; OCI returns
# sources newest-first so element [0] is always the latest available build.
data "oci_containerengine_node_pool_option" "oke" {
  node_pool_option_id = oci_containerengine_cluster.arm_cluster.id
  compartment_id      = var.compartment_ocid
}

locals {
  _k8s_ver = replace(local.kubernetes_version, "v", "")
  arm64_oke_images = [
    for src in data.oci_containerengine_node_pool_option.oke.sources : src
    if can(regex("Oracle-Linux-8\\..*-aarch64-.*-OKE-${local._k8s_ver}-", src.source_name))
  ]
  node_image_id   = local.arm64_oke_images[0].image_id
  node_image_name = local.arm64_oke_images[0].source_name
}

# ── Node Pool ─────────────────────────────────────────────────────────────────────
# Sized for OCI Always Free ARM allotment: 2 OCPU × 12 GB × 1 node = $0/month.
# kubernetes_version tracks the cluster version by default; set
# node_pool_kubernetes_version to lag behind during staged upgrades.

resource "oci_containerengine_node_pool" "arm_pool" {
  compartment_id     = var.compartment_ocid
  cluster_id         = oci_containerengine_cluster.arm_cluster.id
  kubernetes_version = local.node_pool_kubernetes_version
  name               = "${local.cluster_name}-arm-pool"
  node_shape         = "VM.Standard.A1.Flex"
  freeform_tags      = local.freeform_tags

  node_config_details {
    size                                = var.node_count
    is_pv_encryption_in_transit_enabled = true # Encryption in transit enabled

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.private_subnet.id
    }

    node_pool_pod_network_option_details {
      cni_type = "FLANNEL_OVERLAY"
      # max_pods_per_node is silently ignored by OCI for FLANNEL_OVERLAY CNI
      # (only applies to OCI_VCN_IP_NATIVE). Omitting it eliminates perpetual
      # plan drift where OCI always reports 0 on refresh.
    }
  }

  node_shape_config {
    memory_in_gbs = var.node_memory_gb
    ocpus         = var.node_ocpus
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.node_image_id
    boot_volume_size_in_gbs = 50
  }

  initial_node_labels {
    key   = "oci.oraclecloud.com/encrypt-in-transit"
    value = "true"
  }

  initial_node_labels {
    key   = "kubernetes.io/arch"
    value = "arm64"
  }

  initial_node_labels {
    key   = "node.kubernetes.io/instance-type"
    value = "VM.Standard.A1.Flex"
  }
}
