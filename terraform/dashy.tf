
############################################
# 1. Inline YAML  →  locals
############################################
locals {
  dashy_cfg_map = {
    appConfig = {
      title  = "Home Dashboard"
      theme  = "dark"
      layout = "auto"
    }
    sections = [
      {
        name  = "Apps"
        items = [
          {
            title       = "ConvertX"
            icon        = "mdi-file-sync"
            url         = "http://convertx.home.local"
            statusCheck = true
          }
        ]
      }
    ]
  }

  dashy_cfg_yaml = yamlencode(local.dashy_cfg_map)
}

############################################
# 2. ConfigMap  (Dashy reads this file)
############################################
resource "kubernetes_config_map" "dashy_cfg" {
  metadata {
    name      = "dashy-config"
    namespace = kubernetes_namespace.home.metadata[0].name
  }

  data = {
    "conf.yml" = local.dashy_cfg_yaml
  }
}




############################
# 3. Deployment (Docker-hub image)
############################
resource "kubernetes_deployment" "dashy" {
  metadata {
    name      = "dashy"
    namespace = kubernetes_namespace.home.metadata[0].name
    labels    = { app = "dashy" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "dashy" } }

    template {
      metadata { labels = { app = "dashy" } }

      spec {
        container {
          name  = "dashy"
          image = "lissy93/dashy:latest"

          # Dashy listens on 8080
          port { container_port = 8080 }

          # Mount our config at /app/user-data/conf.yml
          volume_mount {
            name       = "config"
            mount_path = "/app/user-data/conf.yml"
            sub_path   = "conf.yml"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.dashy_cfg.metadata[0].name
          }
        }
      }
    }
  }
}

############################
# 4. Service (NodePort 32001)
############################
resource "kubernetes_service" "dashy" {
  metadata {
    name      = "dashy"
    namespace = kubernetes_namespace.home.metadata[0].name
  }

  spec {
    selector = { app = "dashy" }
    port {
      port        = 8080      # inside cluster
      target_port = 8080
      node_port   = 32001
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "dashy" {
  metadata {
    name      = "dashy"
    namespace = kubernetes_namespace.home.metadata[0].name
    annotations = {
      # keep HTTPS off in Minikube for now
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }

  spec {
    rule {
      host = "dashy.home.local"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.dashy.metadata[0].name   # points to the Service you already have
              port { number = 8080 }                             # cluster-internal port
            }
          }
        }
      }
    }
  }
}
