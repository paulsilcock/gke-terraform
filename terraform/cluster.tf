resource "google_container_cluster" "main" {
  provider = google-beta

  name     = var.cluster_name
  location = var.location

  # This disables "Node Auto Provisioning", which reates additional node pools to 
  # meet demand. Instead allow provisioned node pools to scale.
  cluster_autoscaling {
    enabled = false
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }
}

resource "google_container_node_pool" "generic" {
  name     = "${var.cluster_name}-generic-nodepool"
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
    machine_type = "e2-micro"

    disk_size_gb = 15

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

resource "google_container_node_pool" "workloads" {
  name     = "${var.cluster_name}-workload-nodepool"
  location = var.location
  cluster  = google_container_cluster.main.name

  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = 2
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = true
    machine_type = "e2-standard-2"

    disk_size_gb = 20

    service_account = google_service_account.main.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    taint {
      key    = "type"
      value  = "workload"
      effect = "NO_SCHEDULE"
    }
  }

  timeouts {
    create = "20m"
    update = "20m"
  }
}

resource "google_container_node_pool" "gpu" {
  name     = "${var.cluster_name}-gpu-nodepool"
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

    disk_size_gb = 20

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

data "kubectl_file_documents" "namespaces" {
  content = file("../manifests/namespaces.yaml")
}

resource "kubectl_manifest" "namespaces" {
  count     = length(data.kubectl_file_documents.namespaces.documents)
  yaml_body = element(data.kubectl_file_documents.namespaces.documents, count.index)
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
