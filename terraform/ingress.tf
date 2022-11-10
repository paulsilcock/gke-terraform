resource "google_compute_global_address" "ingress" {
  provider = google-beta
  name     = "ingress-nginx-lb"
  project  = var.project_id
  address  = "34.89.32.55"
}

resource "helm_release" "nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.4.0"

  set {
    name  = "controller.service.loadBalancerIP"
    value = google_compute_global_address.ingress.address
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }
}
