data "kubectl_file_documents" "argocd" {
  content = file("../manifests/install-argocd.yaml")
}

resource "kubectl_manifest" "argocd" {
  depends_on = [
    kubectl_manifest.namespaces,
    kubectl_manifest.nginx,
    kubectl_manifest.certmanager,
    kubectl_manifest.cert_issuer
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
