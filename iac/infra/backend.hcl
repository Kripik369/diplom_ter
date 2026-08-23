bucket                      = "tf-state-andrey-prod-2026"
key                         = "prod/k8s_infra.tfstate"
region                      = "us-east-1" # <-- ВАЖНО: используем заглушечный регион AWS
skip_region_validation      = true
skip_credentials_validation = true
use_path_style              = true
endpoints = {
  s3 = "https://storage.yandexcloud.net"
}
