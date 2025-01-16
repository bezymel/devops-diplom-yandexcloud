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
  service_account_key_file = file("/home/bezumel/authorized_key.json") # Путь к вашему ключу сервисного аккаунта
  folder_id          = var.folder_id  # ID вашей папки в Яндекс.Облаке
  zone               = "ru-central1-b"  # Зона, где будет развернут кластер
}

resource "yandex_storage_bucket" "my_bucket" {
  name     = "my-bucket-name"
  location = "ru-central1"
}

output "bucket_id" {
  value = yandex_storage_bucket.my_bucket.id
}
