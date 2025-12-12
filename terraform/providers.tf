################################################################################
# Provider Configuration
################################################################################
# Configures providers for Rackspace Spot, Kubernetes, and Helm.
################################################################################

provider "spot" {
  token = var.rackspace_spot_token
}

# Kubernetes and Helm providers configured after cloudspace creation
provider "kubernetes" {
  host     = module.cloudspace.api_server_host
  token    = module.cloudspace.api_server_token
  insecure = module.cloudspace.insecure
}

provider "helm" {
  kubernetes {
    host     = module.cloudspace.api_server_host
    token    = module.cloudspace.api_server_token
    insecure = module.cloudspace.insecure
  }
}

# kubectl provider for ArgoCD Application CRDs (doesn't validate CRDs at plan time)
provider "kubectl" {
  host             = module.cloudspace.api_server_host
  token            = module.cloudspace.api_server_token
  insecure         = module.cloudspace.insecure
  load_config_file = false
}
