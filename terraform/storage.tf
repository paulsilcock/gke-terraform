# Allow terraform service account to specify IAM policies on storage buckets
resource "google_project_iam_member" "terraform-binding" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${data.google_service_account.terraform-sa.email}"
}

# Storage bucket used for DVC data
resource "google_storage_bucket" "dvcremote" {
  depends_on = [
    google_project_iam_member.terraform-binding
  ]
  name                        = "dvcremote-pauljs-io"
  location                    = var.region
  uniform_bucket_level_access = true
}

# Policy to allow DVC service account access to bucket
data "google_iam_policy" "dvc-bucket-access" {
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "serviceAccount:${google_service_account.dvc-gsa.email}"
    ]
  }

  binding {
    role = "roles/storage.objectCreator"
    members = [
      "serviceAccount:${google_service_account.dvc-gsa.email}"
    ]
  }

  binding {
    role = "roles/storage.legacyBucketReader"
    members = [
      "serviceAccount:${google_service_account.dvc-gsa.email}"
    ]
  }
}

# Bind policy to bucket
resource "google_storage_bucket_iam_policy" "policy" {
  depends_on = [
    google_project_iam_member.terraform-binding
  ]
  bucket      = google_storage_bucket.dvcremote.name
  policy_data = data.google_iam_policy.dvc-bucket-access.policy_data
}

# Make DVC service account a workload identity user. This allows a K8s service 
# account called `dvc-remote` from the `dev` namespace to impersonate the 
# GCP `dvc-remote` service account (see "[dev/dvc-remote]" in the `member` 
# attribute)
resource "google_service_account_iam_member" "dvc-gsa" {
  service_account_id = google_service_account.dvc-gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[dev/dvc-remote]"
}

# Create a K8s service account that can read/write to our DVC remote storage.
# The `iam.gke.io/gcp-service-account` annotation binds it to the appropriate 
# GCP service account.
resource "kubectl_manifest" "ksa-binding" {
  depends_on = [
    kubectl_manifest.namespaces
  ]
  yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    iam.gke.io/gcp-service-account: dvc-remote@${var.project_id}.iam.gserviceaccount.com
  name: dvc-remote
  namespace: dev
YAML
}
