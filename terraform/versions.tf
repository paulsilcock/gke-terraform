terraform {
  required_version = ">= 0.15"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.0"
    }
  }
  backend "gcs" {
    bucket = "terraform-backend-pauljs-io"
    prefix = "argocd-terraform"
  }
}
