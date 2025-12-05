################################################################################
# Terraform Provider Requirements
################################################################################
# This file defines the required providers for the Rackspace Spot infrastructure.
#
# Provider: rackerlabs/spot
# Docs: https://registry.terraform.io/providers/rackerlabs/spot/latest/docs
################################################################################

terraform {
  required_version = ">= 1.5.0"

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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
