data "kustomization_build" "argocd" {
  provider = kustomization

  path = "${path.root}/../manifests/argocd"
}

resource "kubectl_manifest" "argocd" {
  depends_on = [
    kubectl_manifest.namespaces,
    kubectl_manifest.nginx,
    kubectl_manifest.certmanager,
    kubectl_manifest.cert_issuer
  ]

  for_each  = data.kustomization_build.argocd.manifests
  yaml_body = each.value

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
