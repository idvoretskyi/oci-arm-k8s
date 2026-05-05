/**
 * Version constraints for the Monitoring Module.
 * Aligned with tf/provider.tf constraints.
 */

terraform {
  required_version = ">= 1.6.0" # OpenTofu 1.6+

  required_providers {
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
