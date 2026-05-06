# CIS Compliance Notes — OCI ARM OKE Demo Cluster

This document maps CIS Benchmark controls to the OpenTofu configuration in this repository.
Target benchmarks: **CIS Kubernetes Benchmark v1.9** and **CIS OCI Foundations Benchmark v2.0**.

---

## In Scope — Addressed by this Configuration

### CIS Kubernetes Benchmark

| Control | Description | Implementation |
|---------|-------------|----------------|
| 5.1.1 | Ensure the Kubernetes dashboard is not deployed | `is_kubernetes_dashboard_enabled = false` in `tf/cluster.tf` |
| 5.1.2 | Ensure that the Tiller (Helm v2) service is not deployed | `is_tiller_enabled = false` in `tf/cluster.tf` |
| 5.2.x | Pod Security Standards | PSP removed (deprecated in K8s 1.21, removed in 1.25). Use Pod Security Admission labels on namespaces or a policy engine (see below). |
| 5.4.2 | Restrict Kubernetes API server access | `api_allowed_cidrs` variable (default `["0.0.0.0/0"]` for demo). **Set to your IP range in production.** Enforced via NSG rules in `tf/network.tf`. |
| 5.6.x | Encryption at rest / in transit | OCI encrypts boot volumes and block volumes at rest by default. `is_pv_encryption_in_transit_enabled = true` on the node pool. |

### CIS OCI Foundations Benchmark

| Control | Description | Implementation |
|---------|-------------|----------------|
| 2.x | Network least privilege | Private worker subnet has its own security list (`private_sl`) with no inbound API port (6443). Public subnet (`public_sl`) exposes 6443 only to `api_allowed_cidrs`. |
| 3.x | Logging | OCI Audit captures all API calls automatically at the tenancy level (no IaC required). VCN flow logs available via `enable_flow_logs = true`. |
| 4.x | Networking | VCN flow logs behind `enable_flow_logs` variable (`tf/network.tf`). NAT gateway (default on, free on OCI) provides internet egress from private workers; OCI Service Gateway provides direct low-latency access to OCI services. Disable NAT (`enable_nat_gateway = false`) only for air-gapped deployments with a custom image mirror. |
| 6.x | Asset / resource tagging | All OCI resources tagged with `ManagedBy=OpenTofu`, `Environment=demo`, `Purpose=CNCF-demo`, `CostCenter=free-tier`, `Cluster=<name>` via `local.freeform_tags`. |

---

## Partially Addressed — Requires Runtime Configuration

These controls are not fully enforceable at the IaC layer. They require additional runtime setup after the cluster is deployed.

| Control | What to do |
|---------|------------|
| CIS K8s 5.2.x — Pod Security | Apply Pod Security Admission labels to namespaces: `kubectl label ns default pod-security.kubernetes.io/enforce=baseline`. For stricter enforcement use [Kyverno](https://kyverno.io) or [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper). |
| CIS K8s 5.3.x — Network Policies | Apply `NetworkPolicy` resources to restrict pod-to-pod traffic. Flannel (the CNI used here) supports `NetworkPolicy` via a policy controller. |
| CIS K8s 5.4.1 — Private API endpoint | The demo uses a public API endpoint. For production, set `is_public_ip_enabled = false` and add a bastion/VPN. Increases cost and complexity significantly. |
| CIS K8s 5.7.x — RBAC | Configure RBAC roles/bindings per workload. OKE creates default cluster-admin binding for the deploying user. |
| CIS OCI 2.x — IAM least privilege | Create a dedicated OCI IAM group and policy with minimum OKE/VCN/Compute permissions for the deploy user. Currently using the profile user's existing permissions. |
| CIS OCI 2.x — MFA | Enable MFA for the OCI IAM user. Not configurable via OpenTofu. |

---

## Out of Scope — Not Addressed by this Configuration

These controls require tenancy-level setup or significant architectural additions outside the scope of a demo cluster.

| Control | Reason |
|---------|--------|
| CIS OCI 1.x — Cloud Guard | Tenancy-level setting; out of scope for per-cluster IaC. Enable via the OCI Console. |
| CIS OCI 2.3 — Object storage bucket policies | No object storage buckets are created here. |
| CIS K8s — Image signing / admission | Requires Notary v2 / Sigstore integration; out of scope for demo. |
| CIS K8s — Runtime threat detection | Install [Falco](https://falco.org) post-deploy for syscall-level monitoring. |
| CIS K8s — Secrets encryption at rest (KMS) | OCI KMS key for etcd secrets encryption is available in Enhanced OKE clusters only (costs ~$0.10/hr). Not compatible with Always Free. |
| CIS K8s — Audit log policy | OKE Basic clusters do not expose API server audit log configuration. Enhanced clusters support this. |
| CIS K8s 5.4.1 — Private cluster | Adds bastion + private DNS; breaks Always Free $0 goal. |

---

## Hardening for Production

Before promoting this cluster beyond demo use:

1. **Restrict API CIDRs**: set `api_allowed_cidrs` to your office/VPN IP range.
2. **Enable flow logs**: set `enable_flow_logs = true`.
3. **Namespace Pod Security**: apply PSA labels or deploy Kyverno.
4. **RBAC audit**: remove default cluster-admin bindings for service accounts.
5. **Dedicated IAM user**: create a least-privilege OCI IAM group/policy for the deploy principal.
6. **Enable Cloud Guard** at the tenancy level via OCI Console.
7. **Enable MFA** for the OCI user running `tofu apply`.
8. **Private endpoint**: consider moving to an Enhanced OKE cluster with a private API endpoint behind a bastion if the workload is sensitive.
