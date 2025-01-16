terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.69.0"
    }
  }
  required_version = ">= 0.13"
}
}

resource "yandex_storage_bucket" "my_bucket" {
  name     = "my-bucket-name"
  location = "ru-central1"
}

output "bucket_id" {
  value = yandex_storage_bucket.my_bucket.id
}
