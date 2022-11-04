
# Create a workload pool & provider to allow external identities (e.g. Github) 
# to impersonate GCP servie accounts. Primary use case is to allow Github actions 
# to submit Argo Workflows
resource "google_iam_workload_identity_pool" "workload-pool" {
  workload_identity_pool_id = "workload-pool"
  display_name              = "Workload pool"
  description               = "Identity pool for external access (e.g. Github)"
}
resource "google_iam_workload_identity_pool_provider" "github-provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.workload-pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  attribute_mapping = {
    "google.subject" : "assertion.sub"
    "attribute.repository" : "assertion.repository"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow the Argo Workflow GCP service account to view clusters. This 
# enables authentication with the cluster, but nothing else. We can 
# bind this account to Roles/ClusterRoles to provide additional permissions.
resource "google_project_iam_binding" "cluster-viewer" {
  project = var.project_id
  role    = "roles/container.clusterViewer"
  members = [
    "serviceAccount:${google_service_account.argo-workflow.email}"
  ]
}

# Allow external identities from the workload pool that have the repository attribute 
# value `paulsilcock/mlops` to impersonate the Argo Workflow GCP service account.
# This allows Github actions to publish images to our registry, and submit Argo Workflows.
resource "google_service_account_iam_member" "argo-workflow-github-access" {
  service_account_id = google_service_account.argo-workflow.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.workload-pool.name}/attribute.repository/paulsilcock/mlops"
}

# Allow external identities from the workload pool that have the repository attribute 
# value `paulsilcock/mlops` to impersonate the DVC Remote GCP service account.
# This allows Github actions to push/pull to our DVC remote storage bucket.
resource "google_service_account_iam_member" "dvc-remote-github-access" {
  service_account_id = google_service_account.dvc-gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.workload-pool.name}/attribute.repository/paulsilcock/mlops"
}
