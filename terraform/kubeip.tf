# Allow kube-ip-manager to assign static IPs
resource "google_project_iam_custom_role" "kubeip_role" {
  role_id     = "kubeip_role"
  title       = "KubeIP Role"
  description = "required permissions to run KubeIP"
  stage       = "GA"
  project     = var.project_id
  permissions = ["compute.addresses.list", "compute.instances.addAccessConfig", "compute.instances.deleteAccessConfig", "compute.instances.get", "compute.instances.list", "compute.projects.get", "container.clusters.get", "container.clusters.list", "resourcemanager.projects.get", "compute.networks.useExternalIp", "compute.subnetworks.useExternalIp", "compute.addresses.use"]
}
resource "google_project_iam_member" "kubeip_role_binding" {
  role       = "projects/${var.project_id}/roles/kubeip_role"
  project    = var.project_id
  member     = "serviceAccount:kube-ip-manager@${var.project_id}.iam.gserviceaccount.com"
  depends_on = [google_service_account.kubeip_service_account]
}
resource "google_service_account_iam_member" "sa_iam_member" {
  service_account_id = google_service_account.kubeip_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kube-system/kube-ip]"
}

# Configure the KubeIP application to assign IPs labelled 
# "kubeip=k8s-cluster" to nodes from the "ingress-pool" 
# node pool
resource "kubernetes_config_map" "kubeip_configmap" {
  metadata {
    name      = "kubeip-config"
    namespace = "kube-system"
    labels = {
      "app" = "kubeip"
    }
  }

  data = {
    "KUBEIP_LABELKEY"            = "kubeip"
    "KUBEIP_LABELVALUE"          = var.cluster_name
    "KUBEIP_NODEPOOL"            = google_container_node_pool.ingress.name
    "KUBEIP_FORCEASSIGNMENT"     = "true"
    "KUBEIP_ADDITIONALNODEPOOLS" = ""
    "KUBEIP_TICKER"              = "5"
    "KUBEIP_ALLNODEPOOLS"        = "false"
  }
}

# Use k8s service account to run KubeIP, bind to kube-ip-manager Google service account
resource "kubernetes_service_account" "kubeip" {
  metadata {
    name      = "kube-ip"
    namespace = "kube-system"
    annotations = {
      "iam.gke.io/gcp-service-account" = "${google_service_account.kubeip_service_account.email}"
    }
  }
  automount_service_account_token = true
}

# ...create cluster role for kube-ip k8s service account, to allow 
# patching of nodes
resource "kubernetes_cluster_role" "kubeip" {
  metadata {
    name = "kubeip"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch", "patch"]
  }
}
resource "kubernetes_cluster_role_binding" "kubeip" {
  metadata {
    name = "kubeip"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kubeip.metadata.0.name
    namespace = "kube-system"
  }
}

# Deploy KubeIP
resource "kubernetes_deployment" "kubeip" {
  metadata {
    name      = "kubeip"
    namespace = "kube-system"
    labels = {
      app = "kubeip"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kubeip"
      }
    }

    template {
      metadata {
        labels = {
          app = "kubeip"
        }
      }

      spec {
        container {
          image = "doitintl/kubeip:latest"
          name  = "kubeip"

          env_from {
            config_map_ref {
              name = kubernetes_config_map.kubeip_configmap.metadata.0.name
            }
          }

          resources {
            limits = {
              cpu    = "50"
              memory = "50Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "50Mi"
            }
          }
        }
        automount_service_account_token = true
        node_selector = {
          "cloud.google.com/gke-nodepool" = google_container_node_pool.generic.name
        }
        restart_policy       = "Always"
        priority_class_name  = "system-node-critical"
        service_account_name = kubernetes_service_account.kubeip.metadata.0.name
      }
    }
  }

  timeouts {
    create = "3m"
    update = "3m"
    delete = "3m"
  }
}
