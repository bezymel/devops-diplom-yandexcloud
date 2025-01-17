terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }

   backend "s3" {
    endpoint                    = "https://storage.yandexcloud.net"
    bucket                      = "diplom-project-nemcev"
    region                      = "ru-central1"
    key                         = "terraform.tfstate"
    access_key                  = "my_access_key"
    secret_key                  = "my_secret_key"
    skip_region_validation      = true
    skip_credentials_validation = true
  }

  required_version = ">=1.4"
  }

provider "yandex" {
  token = var.token
  cloud_id = var.cloud_id
  folder_id = var.folder_id
  zone = var.default_zone
}
