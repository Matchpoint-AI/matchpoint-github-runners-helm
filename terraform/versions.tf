################################################################################
# Terraform Configuration
################################################################################
# Version constraints and backend configuration.
# Uses GCS backend for state storage (migrated from tfstate.dev which is defunct).
################################################################################

terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {
    bucket = "matchpoint-tofu-state"
    prefix = "matchpoint-github-runners-helm/prod"
  }

  required_providers {
    spot = {
      source  = "rackerlabs/spot"
      version = "0.1.4" # Pinned to latest v0.1.4 for stability (Issue #159)
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    # Required: State references random provider resources from legacy configuration
    # TODO: Remove after running `terraform state rm` on random resources
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    # kubectl provider for CRD resources that don't exist at plan time
    # Unlike kubernetes_manifest, kubectl_manifest doesn't validate CRDs during plan
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    # Required for time_sleep resource
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10"
    }
  }
}
# PR #170: Trigger terraform check for force-delete fix
