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
