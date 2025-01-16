terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.69.0"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = file("/home/bezumel/authorized_key.json")
#  token              = var.token
  folder_id          = var.folder_id
  zone               = var.zone
}

resource "yandex_iam_service_account" "my_service_account" {
  name        = "bezumel"
  description = "Description of the service account."           
}
