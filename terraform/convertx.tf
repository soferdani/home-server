# 2. Secret
resource "kubernetes_secret" "convertx" {
  metadata {
    name      = "convertx-secret"
    namespace = kubernetes_namespace.home.metadata[0].name
  }

  data = {
    # Terraform 1.2+ has base64encode()
    JWT_SECRET = base64encode(var.jwt_secret)
  }

  type = "Opaque"
}

# 3. PVC
resource "kubernetes_persistent_volume_claim" "convertx" {
  metadata {
    name      = "convertx-data"
    namespace = kubernetes_namespace.home.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = { storage = "5Gi" }
    }
  }
}

# 4. Deployment
resource "kubernetes_deployment" "convertx" {
  metadata {
    name      = "convertx"
    namespace = kubernetes_namespace.home.metadata[0].name
    labels    = { app = "convertx" }
  }

  spec {
    replicas = 1

    selector { match_labels = { app = "convertx" } }

    template {
      metadata { labels = { app = "convertx" } }

      spec {
        container {
          name  = "convertx"
          image = "ghcr.io/c4illin/convertx:latest"

          port { container_port = 3000 }

          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.convertx.metadata[0].name
                key  = "JWT_SECRET"
              }
            }
          }

          env {
            name  = "HTTP_ALLOWED"
            value = "true"
          }

          env {
            name  = "ALLOW_UNAUTHENTICATED"
            value = "true"
          }

          volume_mount {
            name       = "data"
            mount_path = "/app/data"
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.convertx.metadata[0].name
          }
        }
      }
    }
  }
}

# 5. Service
resource "kubernetes_service" "convertx" {
  metadata {
    name      = "convertx"
    namespace = kubernetes_namespace.home.metadata[0].name
  }
  spec {
    selector = { app = "convertx" }
    port {
      port        = 3000
      target_port = 3000
      node_port   = 32000   # fixed port for convenience
    }
    type = "NodePort"
  }
}
