
resource "helm_release" "external_secrets" {
  name = "external-secrets"

  values = [
    <<EOT
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: secret-manager@${var.project_id}.iam.gserviceaccount.com
EOT
  ]

  namespace        = "es"
  create_namespace = true
  chart            = "https://github.com/external-secrets/external-secrets/releases/download/helm-chart-0.6.1/external-secrets-0.6.1.tgz"
}

# Allow secret manager GSA to create secrets
resource "google_project_iam_binding" "secret_manager_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.secret_manager.email}"
  ]
}

# Allow external-secrets KSA to impersonate secrets-manager GSA
resource "google_service_account_iam_member" "secret_manager_workload_id" {
  service_account_id = google_service_account.secret_manager.name
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
  name: cluster-secret-store
spec:
  provider:
    gcpsm:
      projectID: ${var.project_id}
YAML
}
