terraform {
  required_version = ">= 0.15"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
  backend "gcs" {
    bucket = "terraform-backend-pauljs-io"
    prefix = "argocd-terraform"
  }
}
