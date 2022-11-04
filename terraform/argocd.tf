data "kustomization_build" "argocd" {
  provider = kustomization

  path = "${path.root}/../manifests/argocd"
}

resource "kustomization_resource" "argocd" {
  provider = kustomization

  depends_on = [
    kubectl_manifest.namespaces,
    kubectl_manifest.cert_issuer,
    helm_release.external_secrets
  ]

  for_each = data.kustomization_build.argocd.ids

  manifest = data.kustomization_build.argocd.manifests[each.value]
}

data "kubectl_file_documents" "rootapp" {
  content = file("../manifests/root-app.yaml")
}

resource "kubectl_manifest" "rootapp" {
  depends_on = [
    kustomization_resource.argocd
  ]
  count     = length(data.kubectl_file_documents.rootapp.documents)
  yaml_body = element(data.kubectl_file_documents.rootapp.documents, count.index)
}
