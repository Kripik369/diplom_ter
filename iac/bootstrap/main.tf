terraform {
  required_version = ">= 1.5.0"
  
  # Бэкенд S3 читает настройки из backend.hcl
  backend "s3" {}

  required_providers {
    yandex = { source = "yandex-cloud/yandex" }
    aws    = { 
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
  }
}

provider "yandex" {
  zone = "ru-central1-a"
}

# Провайдер AWS нужен ТОЛЬКО для работы бэкенда S3
provider "aws" {
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  endpoints                   = { s3 = "https://storage.yandexcloud.net" }
  region                      = "ru-central1"
  access_key                  = var.aws_access_key_id
  secret_key                  = var.aws_secret_access_key
}

variable "yc_token" {}
variable "yc_cloud_id" {}
variable "yc_folder_id" {}
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}

locals {
  infra_sa_id = "aje8h6ucqbah6dv1p5ie"
}

resource "yandex_iam_service_account" "infra_sa" {
  name = "k8s-infra-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.infra_sa.id}"
}

resource "yandex_kubernetes_cluster" "zonal" {
  name       = "budget-k8s"
  network_id = yandex_vpc_network.net.id

  master {
    regional {
      region = "ru-central1"
      location { zone = "ru-central1-a"; subnet_id = yandex_vpc_subnet.a.id }
      location { zone = "ru-central1-b"; subnet_id = yandex_vpc_subnet.b.id }
      location { zone = "ru-central1-d"; subnet_id = yandex_vpc_subnet.d.id }
    }
    public_ip = true
    version   = "1.32"
  }

  service_account_id      = local.infra_sa_id
  node_service_account_id = local.infra_sa_id
  release_channel         = "REGULAR"
}

resource "yandex_kubernetes_node_group" "preemptible" {
  cluster_id = yandex_kubernetes_cluster.zonal.id
  name       = "spot-group"

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    location { zone = "ru-central1-a" }
    location { zone = "ru-central1-b" }
    location { zone = "ru-central1-d" }
  }

  instance_template {
    platform_id = "standard-v3"
    resources {
      memory          = 2
      cores           = 2
      core_fraction   = 50
    }
    boot_disk {
      type = "network-hdd"
      size = 32
    }
    scheduling_policy {
      preemptible = true
    }
  }
}

output "kubernetes_cluster_id" { value = yandex_kubernetes_cluster.zonal.id }
