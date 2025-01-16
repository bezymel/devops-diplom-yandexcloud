terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.69.0"
    }
  }

  backend "s3" {
    bucket = "my-bucket-name"                                 
    key    = "terraform/state"          
    region = "ru-central1"              
  }
}

provider "yandex" {
  service_account_key = file("/home/bezumel/authorized_key.json")  
  cloud_id           = "b1g8tssboq6kq6qsl5pb" 
  folder_id          = "b1gaadh5jrnspg1gklri"                   
}

resource "yandex_storage_bucket" "my_bucket" {
  name     = "my-bucket-name"   
  location = "ru-central1"      
}
