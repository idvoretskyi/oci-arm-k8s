# ── VCN ─────────────────────────────────────────────────────────────────────────

resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "${local.cluster_name}-vcn"
  dns_label      = "armokecluster"
  freeform_tags  = local.freeform_tags
}

# ── Internet Gateway (public subnet / LB / API endpoint) ────────────────────────

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${local.cluster_name}-igw"
  freeform_tags  = local.freeform_tags
}

# ── Service Gateway ──────────────────────────────────────────────────────────────
# Free. Routes worker node traffic to OCI services (registry, object storage, etc.)
# without going over the public internet — no NAT gateway required for demo usage.

data "oci_core_services" "all" {}

locals {
  all_services_id   = [for s in data.oci_core_services.all.services : s.id if length(regexall("all-.*-services-in-oracle-services-network", s.cidr_block)) > 0][0]
  all_services_cidr = [for s in data.oci_core_services.all.services : s.cidr_block if length(regexall("all-.*-services-in-oracle-services-network", s.cidr_block)) > 0][0]
}

resource "oci_core_service_gateway" "sgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${local.cluster_name}-sgw"
  freeform_tags  = local.freeform_tags

  services {
    service_id = local.all_services_id
  }
}

# ── NAT Gateway (optional — costs ~$32/month) ────────────────────────────────────
# Enable via: -var='enable_nat_gateway=true'
# Required only when pods must pull images from DockerHub / GitHub.

resource "oci_core_nat_gateway" "ngw" {
  count          = var.enable_nat_gateway ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${local.cluster_name}-ngw"
  freeform_tags  = local.freeform_tags
}

# ── Route tables ─────────────────────────────────────────────────────────────────

resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${local.cluster_name}-public-rt"
  freeform_tags  = local.freeform_tags

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${local.cluster_name}-private-rt"
  freeform_tags  = local.freeform_tags

  # OCI services (registry, object storage) via Service Gateway — always present.
  route_rules {
    destination_type  = "SERVICE_CIDR_BLOCK"
    destination       = local.all_services_cidr
    network_entity_id = oci_core_service_gateway.sgw.id
  }

  # Unrestricted internet egress via NAT — only when explicitly enabled.
  dynamic "route_rules" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      destination       = "0.0.0.0/0"
      network_entity_id = oci_core_nat_gateway.ngw[0].id
    }
  }
}

# ── Security lists ────────────────────────────────────────────────────────────────
# CIS: split into public_sl (API port exposed) and private_sl (no API exposure).

# Public subnet security list — API endpoint + LB traffic
resource "oci_core_security_list" "public_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${local.cluster_name}-public-sl"
  freeform_tags  = local.freeform_tags

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "Allow all outbound"
  }

  # Intra-VCN (OKE node↔control-plane communication)
  ingress_security_rules {
    protocol    = "all"
    source      = "10.0.0.0/16"
    description = "Intra-VCN traffic"
  }

  # Kubernetes API — CIS K8s 5.4.2: restrict via api_allowed_cidrs variable.
  dynamic "ingress_security_rules" {
    for_each = var.api_allowed_cidrs
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      description = "Kubernetes API (6443) from allowed CIDR"
      tcp_options {
        min = 6443
        max = 6443
      }
    }
  }

  # ICMP path MTU discovery (required for OKE)
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "ICMP path MTU discovery"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

# Private subnet security list — worker nodes (no direct API port exposure)
# CIS: private nodes must not accept inbound API traffic from internet.
resource "oci_core_security_list" "private_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${local.cluster_name}-private-sl"
  freeform_tags  = local.freeform_tags

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "Allow all outbound (service gateway routes OCI traffic; NAT optional)"
  }

  # Intra-VCN only (node pools, control plane, LB)
  ingress_security_rules {
    protocol    = "all"
    source      = "10.0.0.0/16"
    description = "Intra-VCN traffic (no direct internet exposure)"
  }

  # ICMP path MTU discovery
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "ICMP path MTU discovery"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

# ── Network Security Group (OKE cluster endpoint) ─────────────────────────────────

resource "oci_core_network_security_group" "oke_cluster_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${local.cluster_name}-oke-cluster-nsg"
  freeform_tags  = local.freeform_tags
}

# API ingress — restricted to var.api_allowed_cidrs (CIS K8s 5.4.2)
# CKV_OCI_21: OCI NSG security rules do not support is_stateless (that field is
# specific to security list rules). NSG rules are inherently stateful; skip is correct.
resource "oci_core_network_security_group_security_rule" "oke_cluster_nsg_ingress_k8s" { #checkov:skip=CKV_OCI_21:OCI NSG rules have no is_stateless attribute; stateless is a security-list-only concept
  for_each = toset(var.api_allowed_cidrs)

  network_security_group_id = oci_core_network_security_group.oke_cluster_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"
  description               = "Kubernetes API (6443) from allowed CIDR"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# CKV2_OCI_2 / CKV2_OCI_3: Do not allow egress on RDP (TCP/UDP 3389).
# Split into four rules covering TCP 1-3388, TCP 3390-65535,
# UDP 1-3388, UDP 3390-65535, plus ICMP — effectively full egress minus 3389.

resource "oci_core_network_security_group_security_rule" "oke_cluster_nsg_egress_tcp_low" {
  network_security_group_id = oci_core_network_security_group.oke_cluster_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6" # TCP
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow TCP 1-3388 outbound from OKE control plane"

  tcp_options {
    destination_port_range {
      min = 1
      max = 3388
    }
  }
}

resource "oci_core_network_security_group_security_rule" "oke_cluster_nsg_egress_tcp_high" {
  network_security_group_id = oci_core_network_security_group.oke_cluster_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6" # TCP
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow TCP 3390-65535 outbound from OKE control plane"

  tcp_options {
    destination_port_range {
      min = 3390
      max = 65535
    }
  }
}

resource "oci_core_network_security_group_security_rule" "oke_cluster_nsg_egress_udp_low" {
  network_security_group_id = oci_core_network_security_group.oke_cluster_nsg.id
  direction                 = "EGRESS"
  protocol                  = "17" # UDP
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow UDP 1-3388 outbound from OKE control plane"

  udp_options {
    destination_port_range {
      min = 1
      max = 3388
    }
  }
}

resource "oci_core_network_security_group_security_rule" "oke_cluster_nsg_egress_udp_high" {
  network_security_group_id = oci_core_network_security_group.oke_cluster_nsg.id
  direction                 = "EGRESS"
  protocol                  = "17" # UDP
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow UDP 3390-65535 outbound from OKE control plane"

  udp_options {
    destination_port_range {
      min = 3390
      max = 65535
    }
  }
}

resource "oci_core_network_security_group_security_rule" "oke_cluster_nsg_egress_icmp" { #checkov:skip=CKV2_OCI_2:ICMP has no port concept; protocol 1 cannot carry RDP (TCP/3389)
  network_security_group_id = oci_core_network_security_group.oke_cluster_nsg.id
  direction                 = "EGRESS"
  protocol                  = "1" # ICMP
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow ICMP outbound from OKE control plane"
}

# ── Subnets ───────────────────────────────────────────────────────────────────────

resource "oci_core_subnet" "public_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "${local.cluster_name}-public"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public_rt.id
  security_list_ids          = [oci_core_security_list.public_sl.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.freeform_tags
}

resource "oci_core_subnet" "private_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn.id
  cidr_block                 = "10.0.2.0/24"
  display_name               = "${local.cluster_name}-private"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.private_rt.id
  security_list_ids          = [oci_core_security_list.private_sl.id]
  prohibit_public_ip_on_vnic = true
  freeform_tags              = local.freeform_tags
}

# ── VCN Flow Logs (CIS OCI 4.x — optional) ───────────────────────────────────────

resource "oci_logging_log_group" "vcn_flow_logs" {
  count          = var.enable_flow_logs ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${local.cluster_name}-vcn-flow-logs"
  freeform_tags  = local.freeform_tags
}

resource "oci_logging_log" "public_subnet_flow_log" {
  count         = var.enable_flow_logs ? 1 : 0
  display_name  = "${local.cluster_name}-public-subnet-flow"
  log_group_id  = oci_logging_log_group.vcn_flow_logs[0].id
  log_type      = "SERVICE"
  freeform_tags = local.freeform_tags

  configuration {
    source {
      category    = "all"
      resource    = oci_core_subnet.public_subnet.id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = 30
}

resource "oci_logging_log" "private_subnet_flow_log" {
  count         = var.enable_flow_logs ? 1 : 0
  display_name  = "${local.cluster_name}-private-subnet-flow"
  log_group_id  = oci_logging_log_group.vcn_flow_logs[0].id
  log_type      = "SERVICE"
  freeform_tags = local.freeform_tags

  configuration {
    source {
      category    = "all"
      resource    = oci_core_subnet.private_subnet.id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = 30
}
