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
  folder_id          = var.folder_id  
  zone               = "ru-central1-b" 
}

