resource "google_compute_address" "ingress" {
  name         = "ingress-nginx-lb"
  address_type = "EXTERNAL"
  region       = var.region
}

output "cluster_ingress_ip" {
  value = google_compute_address.ingress
}

resource "helm_release" "nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.4.0"

  set {
    name  = "controller.service.loadBalancerIP"
    value = google_compute_address.ingress.address
  }
}
