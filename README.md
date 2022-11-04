# GKE Cluster

_Originally forked from [`bharatmicrosystems/argo-cd-example`](https://github.com/bharatmicrosystems/argo-cd-example)_

Provisions a Kubernetes cluster using Google Kubernetes Engine, and deploys an instance of ArgoCD to bootstrap the cluster with applications specified [here](https://github.com/paulsilcock/app-of-apps).

Currently deploys to my Google Cloud Platform account that qualifies for the 90 day free trial (at the time of writing, this is $300 of credit!)

## Quickstart
Prerequisites:
* Install `terraform`
  
Initialise `terraform` to allow `fmt`/`validate` to run locally:
```
terraform -chdir=terraform init -backend=false
```
Install the recommended VSCode [extensions](.vscode/extensions.json). VSCode will auto-format and validate on save.

## Motivation

This started as a place to explore Kubernetes and Infrastructure-as-Code techniques. More recently, the cluster created here is being used to explore various MLOps practices & technologies (see [here](https://github.com/paulsilcock/mlops)).

This doesn't aim to be a one-size-fits all for GKE provisioning - there are plenty of resources on the web already that do a decent job of that. As a self-proclaimed DevOps evangelist (and someone with a rapidly growing interest in MLOps), this repository helps fulfil my particular use-case.

Hopefully this proves useful to anyone looking to explore GKE, although I'd consider this very much a work-in-progress/playground!

### Why not AWS/EKS?
The GCP free trial/free tier is pretty generous, and the control-plane costs are free for a single zonal K8s cluster, saving around $70/month.

## Infrastructure

* Cluster
  * Provisions 3 auto-scaling node pools:
    * Generic - uses shared-core machine types, 1-3 nodes (basically 'keeps the lights on' as cheaply as possible!)
    * Workloads - scales to zero if not in use. Requires pod tolerations.
    * GPU - scales to zero if not in use. Requires pod tolerations.
  * Ingress:
    * Configures `ingress-nginx` to use static (currently hard-coded!) IP address for load balancing
    * Uses `cert-manager` to monitor `Ingress` objects and create `Certificate`s as appropriate. Uses a `ClusterIssuer` to request certificates from [`letsencrypt`](https://letsencrypt.org/)
  * Namespaces
    * Creates `dev`, `staging` and `prod` environment namespaces
    * Note that this is purely for cost reasons (so as not to burn through the GKE free tier credit!)
    * In practice, separate clusters may be more appropriate (although it ultimately depends on your use-case)
* Storage
  * Creates a storage bucket to be used as a `DVC`* remote
  * Adds appropriate IAM policies to allow access
  * *stands for [Data Version Control](https://dvc.org/), and works alongside `git` to track machine learning data sets/models
* Workload Identity Pool
  * Creates a workload pool and adds a Github OIDC provider
  * This allows Github actions to impersonate service accounts, e.g. to submit Argo Workflows
* Artifact Registry
  * _This was created manually..._ although it should be moved here soon
  * Adds appropriate IAM policies to allow read/write access, e.g. to publish images from Github
* ArgoCD
  * Installs ArgoCD and configures a root application to bootstrap the cluster (see [`root-app.yaml`](manifests/root-app.yaml))

## What next?

Infrastructure-as-Code brings many benefits, such as reproducibility, audit history, consistent environments,  lack of manual intervention etc. But for now this repository doesn't _test_ our infrastructure code, which in a real production setting would be quite scary 😆. In the short term:
* Ensure _all_ infrastructure is reproducible
  * Currently the artifact registry and static load balancing IP are manually created
* Come up with an appropriate testing strategy
  * Think linting, unit testing, compliance tests, ephemeral pull request environments etc.
  * Note that any strategy must optimize for _cost_, since we're reliant upon GCP free credit (so a duplicate `staging` cluster would be out of the question unfortunately!)
* Add infrastructure monitoring
  * Something like Prometheus/Thanos along with Grafana feels like a good fit
