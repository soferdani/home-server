##############################################
# terraform/main.tf
##############################################
terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.25" }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

# 1. Namespace
resource "kubernetes_namespace" "home" {
  metadata { name = "home" }
}

