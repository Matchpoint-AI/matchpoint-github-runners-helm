################################################################################
# Terraform Configuration
################################################################################
# Version constraints and backend configuration.
# Uses GCS backend with workspace-aware state paths.
################################################################################

terraform {
  required_version = ">= 1.5.0"

  # Remote state in GCS
  # State path: rackspace-spot/{workspace}/terraform.tfstate
  backend "gcs" {
    bucket = "project-beta-runners-tf-state"
    prefix = "rackspace-spot"
  }

  required_providers {
    spot = {
      source  = "rackerlabs/spot"
      version = "~> 0.1"
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
  }
}
