resource "google_compute_address" "ingress" {
  provider     = google-beta
  name         = "ingress-nginx-lb"
  address_type = "EXTERNAL"
  region       = var.region
  labels = {
    "kubeip" = var.cluster_name
  }
}

output "cluster_ingress_ip" {
  value = google_compute_address.ingress
}

resource "helm_release" "nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.4.0"
  namespace        = "ingress-nginx"
  create_namespace = true


  values = [
    <<EOT
controller:
  hostNetwork: true
  nodeSelector:
    cloud.google.com/gke-nodepool: ${google_container_node_pool.ingress.name}
  tolerations:
  - key: dedicated
    operator: Equal
    value: ingress
    effect: NoSchedule 
EOT
  ]
}
