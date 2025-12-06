################################################################################
# Terraform Configuration
################################################################################
# Version constraints and backend configuration.
# Uses TFstate.dev HTTP backend for state storage.
# Auth: Set TF_HTTP_PASSWORD to a GitHub token with repo scope.
################################################################################

terraform {
  required_version = ">= 1.5.0"

  # Remote state via TFstate.dev
  # Docs: https://tfstate.dev
  backend "http" {
    address        = "https://api.tfstate.dev/github/v1"
    lock_address   = "https://api.tfstate.dev/github/v1/lock"
    unlock_address = "https://api.tfstate.dev/github/v1/lock"
    lock_method    = "PUT"
    unlock_method  = "DELETE"
    username       = "Matchpoint-AI/matchpoint-github-runners-helm"
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
