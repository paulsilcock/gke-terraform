terraform {
  required_version = ">= 0.15"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
  backend "gcs" {
    bucket = "terraform-backend-<project-id>"
    prefix = "argocd-terraform"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.location
}

resource "google_service_account" "main" {
  account_id   = "${var.cluster_name}-sa"
  display_name = "GKE Cluster ${var.cluster_name} Service Account"
}

resource "google_container_cluster" "main" {
  provider = google-beta

  name     = var.cluster_name
  location = var.location

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    resource_limits {
      resource_type = "cpu"
      maximum       = 6
    }
    resource_limits {
      resource_type = "memory"
      maximum       = 24
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "main_spot_nodes" {
  name     = "${var.cluster_name}-nodepool"
  location = var.location
  cluster  = google_container_cluster.main.name

  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = true
    machine_type = "e2-highmem-2"

    service_account = google_service_account.main.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  timeouts {
    create = "20m"
    update = "20m"
  }
}

resource "google_container_node_pool" "gpu_spot_nodes" {
  name     = "${var.cluster_name}-nodepool-gpu"
  location = var.location
  cluster  = google_container_cluster.main.name

  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = 1
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = true
    machine_type = "n1-standard-1"

    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1
    }

    service_account = google_service_account.main.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  timeouts {
    create = "20m"
    update = "20m"
  }
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

data "kubectl_file_documents" "namespaces" {
  content = file("../manifests/namespaces.yaml")
}

resource "kubectl_manifest" "namespaces" {
  count     = length(data.kubectl_file_documents.namespaces.documents)
  yaml_body = element(data.kubectl_file_documents.namespaces.documents, count.index)
}

data "google_service_account" "terraform-sa" {
  account_id = "terraform"
}

# Allow terraform service account to specify IAM policies on storage buckets
resource "google_project_iam_binding" "terraform-binding" {
  project = var.project_id
  role    = "roles/storage.admin"
  members = [
    "serviceAccount:${data.google_service_account.terraform-sa.email}"
  ]
}

resource "google_storage_bucket" "dvcremote" {
  depends_on = [
    google_project_iam_binding.terraform-binding
  ]
  name                        = "dvcremote-pauljs-io"
  location                    = var.region
  uniform_bucket_level_access = true
}

# Create GSA, KSA and bind them
resource "google_service_account" "dvc-gsa" {
  account_id   = "dvc-remote"
  display_name = "DVC remote access"
}
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.dvc-gsa.id
  role    = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[dev/dvc-remote]"
  ]
}

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

# Policy to allow service account access to bucket
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
    google_project_iam_binding.terraform-binding
  ]
  bucket      = google_storage_bucket.dvcremote.name
  policy_data = data.google_iam_policy.dvc-bucket-access.policy_data
}

data "kubectl_file_documents" "argocd" {
  content = file("../manifests/install-argocd.yaml")
}

data "kubectl_file_documents" "certmanager" {
  content = file("../manifests/cert-manager-v1.9.1.yaml")
}

resource "kubectl_manifest" "certmanager" {
  count     = length(data.kubectl_file_documents.certmanager.documents)
  yaml_body = element(data.kubectl_file_documents.certmanager.documents, count.index)
}

data "kubectl_file_documents" "cert_issuer" {
  content = file("../manifests/issuer.yaml")
}

resource "kubectl_manifest" "cert_issuer" {
  count     = length(data.kubectl_file_documents.cert_issuer.documents)
  yaml_body = element(data.kubectl_file_documents.cert_issuer.documents, count.index)
}

data "kubectl_file_documents" "nginx" {
  content = file("../manifests/ingress-nginx-v1.4.0.yaml")
}

resource "kubectl_manifest" "nginx" {
  count     = length(data.kubectl_file_documents.nginx.documents)
  yaml_body = element(data.kubectl_file_documents.nginx.documents, count.index)
}

resource "kubectl_manifest" "argocd" {
  depends_on = [
    kubectl_manifest.namespaces,
    kubectl_manifest.nginx
  ]
  count              = length(data.kubectl_file_documents.argocd.documents)
  yaml_body          = element(data.kubectl_file_documents.argocd.documents, count.index)
  override_namespace = "argocd"
}

data "kubectl_file_documents" "rootapp" {
  content = file("../manifests/root-app.yaml")
}

resource "kubectl_manifest" "rootapp" {
  depends_on = [
    kubectl_manifest.argocd
  ]
  count     = length(data.kubectl_file_documents.rootapp.documents)
  yaml_body = element(data.kubectl_file_documents.rootapp.documents, count.index)
}
