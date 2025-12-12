################################################################################
# ArgoCD Module - GitOps Controller Installation
################################################################################
# Installs ArgoCD via Helm and configures it to watch this repository for
# runner deployments.
#
# Features:
# - Automatic namespace creation
# - Self-bootstrapping ApplicationSet
# - GitHub token management
#
# Docs: https://github.com/argoproj/argo-helm
################################################################################

# Install ArgoCD via Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = var.namespace
  create_namespace = true

  # Don't wait for pods - nodes may not be ready immediately after cloudspace creation
  # ArgoCD pods will schedule automatically once nodepool nodes become available
  # Ref: Issue #17 - ArgoCD helm install times out when nodepool has no ready nodes
  wait    = false
  timeout = 300

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      ingress_enabled     = var.ingress_enabled
      ingress_hosts       = var.ingress_hosts
      admin_password_hash = var.admin_password_hash
    })
  ]
}

# Create namespace for runner applications
resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = "arc-systems"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "matchpoint.ai/component"      = "arc-controller"
    }
  }

  depends_on = [helm_release.argocd]
}

# Create GitHub token secret for ArgoCD repo access
resource "kubernetes_secret" "github_token" {
  metadata {
    name      = "github-token"
    namespace = var.namespace
  }

  data = {
    token = var.github_token
  }

  depends_on = [helm_release.argocd]
}

# Patch ArgoCD repo-server to use GitHub token
resource "kubernetes_config_map_v1_data" "argocd_cm" {
  metadata {
    name      = "argocd-cm"
    namespace = var.namespace
  }

  data = {
    "application.instanceLabelKey"       = "argocd.argoproj.io/instance"
    "server.disable.auth"                = "false"
    "timeout.reconciliation"             = "180s"
    "timeout.hard.reconciliation"        = "0"
    "application.resourceTrackingMethod" = "annotation+label"
  }

  force = true

  depends_on = [helm_release.argocd]
}

# Wait for ArgoCD CRDs to be registered before creating Application resources
# The helm chart installs CRDs, but Kubernetes API needs time to register them
# This prevents "no matches for kind Application in group argoproj.io" errors
resource "time_sleep" "wait_for_argocd_crds" {
  depends_on = [helm_release.argocd]

  create_duration = "30s"
}

# Create the bootstrap application that points to this repository
resource "kubernetes_manifest" "bootstrap_app" {
  count = var.enable_bootstrap_app ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "matchpoint-runners-bootstrap"
      namespace = var.namespace
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        targetRevision = var.git_target_revision
        path           = "argocd"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [time_sleep.wait_for_argocd_crds]
}
