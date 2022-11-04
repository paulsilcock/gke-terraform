# Allow secret manager GSA to create secrets
resource "google_project_iam_binding" "secret_manager_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.secret_manager.email}"
  ]
}

# Allow secret manager GSA to create service account tokens 
resource "google_project_iam_binding" "secret_manager_tokens" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:${google_service_account.secret_manager.email}"
  ]
}

# Allow external-secrets KSA to impersonate secrets-manager GSA
resource "google_service_account_iam_member" "secret_manager_workload_id" {
  service_account_id = google_service_account.secret_manager.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[es/external-secrets]"
}

resource "kubectl_manifest" "cluster_secret_store" {
  depends_on = [
    helm_release.external_secrets
  ]
  yaml_body = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: example
spec:
  provider:
    gcpsm:
      projectID: my-project
      auth:
        workloadIdentity:
          clusterLocation: ${var.region}
          clusterName: ${var.cluster_name}
          clusterProjectID: ${var.project_id}
          serviceAccountRef:
            name: external-secrets
            namespace: es

YAML
}
