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
