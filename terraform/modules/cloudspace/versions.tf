terraform {
  required_providers {
    spot = {
      source  = "rackerlabs/spot"
      version = "~> 0.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
