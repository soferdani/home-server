#####################################################
# Tailscale  •  DaemonSet
#####################################################

locals {
  tailscale_authkey = "tskey-auth-kqJC5X9naT11CNTRL-rVU6n3hg75GELwCEvZnX4G3nrXegbf9m"   # put your real auth key here
}

resource "kubernetes_daemonset" "tailscale" {
  metadata {
    name      = "tailscale"
    namespace = kubernetes_namespace.home.metadata[0].name
    labels    = { app = "tailscale" }
  }

  spec {
    
    selector { match_labels = { app = "tailscale" } }

    template {
      metadata { labels = { app = "tailscale" } }

      spec {
        service_account_name = kubernetes_service_account.tailscale.metadata[0].name
        toleration { operator = "Exists" }

        container {
          name  = "tailscale"
          image = "tailscale/tailscale:latest"

          security_context {
            privileged = true
            capabilities { add = ["NET_ADMIN", "SYS_ADMIN"] }
          }

          env {
            name  = "TS_AUTHKEY"
            value = local.tailscale_authkey      # keep your key
          }
          env {
            name  = "TS_STATE_DIR"
            value = "/var/lib/tailscale"
          }

          volume_mount {
            name       = "state"
            mount_path = "/var/lib/tailscale"
          }

          # NEW – mount /dev/net/tun
          volume_mount {
            name       = "tun-device"
            mount_path = "/dev/net/tun"
          }
        }

        volume {
          name = "state"
          empty_dir {}
        }

        # NEW – hostPath CharDevice for /dev/net/tun
        volume {
          name = "tun-device"
          host_path {
            path = "/dev/net/tun"
            type = "CharDevice"
          }
        }
      }

    }
  }
}


############################
# ServiceAccount
############################
resource "kubernetes_service_account" "tailscale" {
  metadata {
    name      = "tailscale"
    namespace = kubernetes_namespace.home.metadata[0].name
  }
}

############################
# Role – permission to manage ONE secret
############################
resource "kubernetes_role" "tailscale_secret" {
  metadata {
    name      = "tailscale-secret"
    namespace = kubernetes_namespace.home.metadata[0].name
  }

  # Rule A – allow CREATE on any Secret (needed once at startup)
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create"]
  }

  # Rule B – allow GET / UPDATE / PATCH only on the “tailscale” Secret
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["tailscale"]
    verbs          = ["get", "update", "patch"]
  }
}

############################
# RoleBinding
############################
resource "kubernetes_role_binding" "tailscale_secret" {
  metadata {
    name      = "tailscale-secret"
    namespace = kubernetes_namespace.home.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.tailscale_secret.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.tailscale.metadata[0].name
    namespace = kubernetes_namespace.home.metadata[0].name
  }
}
