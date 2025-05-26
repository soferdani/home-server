#####################################################
# Nginx Proxy Manager
#####################################################

resource "kubernetes_persistent_volume_claim" "npm_data" {
  metadata {
    name      = "npm-data"
    namespace = kubernetes_namespace.home.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "npm" {
  metadata {
    name      = "npm"
    namespace = kubernetes_namespace.home.metadata[0].name
    labels    = { app = "npm" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "npm" } }

    template {
      metadata { labels = { app = "npm" } }

      spec {
        container {
          name  = "npm"
          image = "jc21/nginx-proxy-manager:latest"

          env {
            name  = "TZ"
            value = "UTC"
          }
          env {
            name  = "DISABLE_IPV6"
            value = "true"
          }

          port { container_port = 80  }  # HTTP
          port { container_port = 81  }  # UI
          port { container_port = 443 }  # HTTPS

          volume_mount {
            name       = "data"
            mount_path = "/etc/letsencrypt"
            sub_path   = "letsencrypt"
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.npm_data.metadata[0].name
          }
        }
      }
    }
  }
}

# ── Service ────────────────────────────────────────
resource "kubernetes_service" "npm" {
  metadata {
    name      = "npm"
    namespace = kubernetes_namespace.home.metadata[0].name
  }

  spec {
    type     = "NodePort"
    selector = { app = "npm" }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    port {
      name        = "https"
      port        = 443
      target_port = 443
    }

    port {
      name        = "admin"
      port        = 81
      target_port = 81
      node_port   = 32081
    }
  }
}
