#####################################################
# Nextcloud  •  Helm Release
#####################################################

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

#####################################
# 1. Secret  (base-64 encoded data)
#####################################
resource "kubernetes_secret" "nextcloud_db" {
  metadata {
    name      = "nextcloud-db-secret"
    namespace = kubernetes_namespace.home.metadata[0].name
  }

  data = {
    # Keys Bitnami PostgreSQL expects:
    postgres-password = base64encode("ncsupersecret")
    password          = base64encode("ncsupersecret")  # for the app user
    username          = base64encode("ncuser")
  }

  type = "Opaque"
}


resource "helm_release" "nextcloud" {
  name       = "nextcloud"
  namespace  = kubernetes_namespace.home.metadata[0].name
  repository = "https://nextcloud.github.io/helm/"
  chart      = "nextcloud"
  version    = "4.5.0"

  values = [<<EOF
nextcloud:
  host: nextcloud.home.local

ingress:
  enabled: true
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"

persistence:
  enabled: true
  size: 10Gi

postgresql:
  enabled: true
  auth:
    existingSecret: ${kubernetes_secret.nextcloud_db.metadata[0].name}
EOF
  ]
}
