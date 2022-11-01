# Registry is created manually (for now...)
# Allows GKE cluster account to pull images in the cluster
# Allows DVC account to pull images, e.g. for local dev
resource "google_project_iam_binding" "artifact-registry-read" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  members = [
    "serviceAccount:${google_service_account.dvc-gsa.email}",
    "serviceAccount:${google_service_account.main.email}"
  ]
}

# Allows Argo Workflow account to publish images from Github
resource "google_project_iam_binding" "artifact-registry-write" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  members = [
    "serviceAccount:${google_service_account.argo-workflow.email}"
  ]
}
