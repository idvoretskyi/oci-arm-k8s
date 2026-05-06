locals {
  # ── Cluster identity ───────────────────────────────────────────────────────────
  cluster_name = var.cluster_name

  # ── OCI config auto-discovery ─────────────────────────────────────────────────
  # Read ~/.oci/config to derive region and compartment_ocid when not explicitly
  # supplied via variables. This makes `tofu apply` zero-argument for typical
  # local development: credentials, region, and tenancy all come from the same
  # file the OCI CLI uses.
  #
  # Precedence (highest to lowest):
  #   1. Explicit -var / TF_VAR_* / terraform.tfvars value
  #   2. Value parsed from ~/.oci/config ([oci_profile] stanza, default: DEFAULT)
  #   3. Error via check block below

  oci_config_path = pathexpand("~/.oci/config")
  oci_config_raw  = fileexists(local.oci_config_path) ? file(local.oci_config_path) : ""

  # Extract the named profile block (everything between [PROFILE] and the next
  # [SECTION] header or end-of-file).
  _oci_profile_block = try(
    regex(
      "(?ms)^\\[${var.oci_profile}\\][^\\[]*",
      local.oci_config_raw
    ),
    ""
  )

  # Pull individual keys out of the profile block.
  oci_tenancy_from_config = try(regex("(?m)^tenancy\\s*=\\s*(\\S+)", local._oci_profile_block)[0], null)
  oci_region_from_config  = try(regex("(?m)^region\\s*=\\s*(\\S+)", local._oci_profile_block)[0], null)

  # Effective values used throughout the configuration.
  effective_region           = coalesce(var.region, local.oci_region_from_config)
  effective_compartment_ocid = coalesce(var.compartment_ocid, local.oci_tenancy_from_config)
  effective_grafana_password = coalesce(var.grafana_admin_password, random_password.grafana[0].result)

  # ── Kubernetes versions ────────────────────────────────────────────────────────
  # latest_kubernetes_version: last entry in the sorted list OCI returns.
  latest_kubernetes_version = (
    length(data.oci_containerengine_cluster_option.options.kubernetes_versions) > 0 ?
    data.oci_containerengine_cluster_option.options.kubernetes_versions[
      length(data.oci_containerengine_cluster_option.options.kubernetes_versions) - 1
    ] : null
  )

  # kubernetes_version: explicit pin wins; otherwise always-latest.
  # With null (default) every `tofu apply` upgrades the cluster when OCI
  # publishes a newer version — no manual version tracking required.
  kubernetes_version = coalesce(var.kubernetes_version, local.latest_kubernetes_version)

  # node_pool_kubernetes_version: follows cluster by default; can lag behind
  # during staged upgrades (upgrade cluster first, validate, then node pool).
  node_pool_kubernetes_version = coalesce(
    var.node_pool_kubernetes_version,
    local.kubernetes_version
  )

  # ── Resource tagging (CIS + cost tracking) ─────────────────────────────────────
  freeform_tags = {
    Environment = "demo"
    ManagedBy   = "OpenTofu"
    Purpose     = "CNCF-demo"
    CostCenter  = "free-tier"
    Cluster     = local.cluster_name
  }
}

# ── Grafana password auto-generation ──────────────────────────────────────────
# Generated only when var.grafana_admin_password is null (the default).
# The result is stored in state and stable across applies.
resource "random_password" "grafana" {
  count            = var.grafana_admin_password == null ? 1 : 0
  length           = 24
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

# ── Sanity check: ensure region and compartment could be resolved ──────────────
# Triggers a clear error if ~/.oci/config is missing/malformed and neither
# variable was supplied explicitly.
check "oci_config_discoverable" {
  assert {
    condition     = local.effective_region != null && local.effective_compartment_ocid != null
    error_message = "Could not resolve region or compartment_ocid. Either supply -var='region=...' and -var='compartment_ocid=...' explicitly, or ensure ~/.oci/config exists with a valid [${var.oci_profile}] profile containing 'region' and 'tenancy'."
  }
}
