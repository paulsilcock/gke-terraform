provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.location
}

data "google_client_config" "default" {
}

data "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.location
}

provider "kubectl" {
  host  = "https://${data.google_container_cluster.main.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.main.master_auth[0].cluster_ca_certificate,
  )
  load_config_file = false
}

provider "helm" {
  kubernetes {
    host  = data.google_container_cluster.main.endpoint
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.main.master_auth[0].cluster_ca_certificate
    )
  }
}

module "gke_auth" {
  source = "terraform-google-modules/kubernetes-engine/google//modules/auth"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  location     = var.location
}

provider "kustomization" {
  kubeconfig_raw = module.gke_auth.kubeconfig_raw
}
