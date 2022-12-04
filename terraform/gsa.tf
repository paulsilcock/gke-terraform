# Used for Terraform access, created manually
data "google_service_account" "terraform-sa" {
  account_id = "terraform"
}

# Google service account associated with cluster nodes
resource "google_service_account" "main" {
  account_id   = "${var.cluster_name}-sa"
  display_name = "GKE Cluster ${var.cluster_name} Service Account"
}

# Used to read/write to storage bucket used as a DVC remote
resource "google_service_account" "dvc-gsa" {
  account_id   = "dvc-remote"
  display_name = "DVC remote access"
}

# Used to allow submission of Argo Workflows from Github
resource "google_service_account" "argo-workflow" {
  account_id   = "argo-workflow"
  display_name = "Argo workflow management"
}

# Used to interact with GCP Secrets Manager 
resource "google_service_account" "secret_manager" {
  account_id   = "secret-manager"
  display_name = "Secret manager"
}

# Monitors ingress node pool and assigns static IP. 
# Saves us using a costly load balancer, which is overkill for 
# a personal project...
resource "google_service_account" "kubeip_service_account" {
  account_id   = "kube-ip-manager"
  project      = var.project_id
  display_name = "kubeIP"
  depends_on   = [google_project_iam_custom_role.kubeip_role]
}

# Publish images to artifact registry duing CI builds
resource "google_service_account" "registry" {
  account_id   = "registry"
  display_name = "Publish artifacts"
}
