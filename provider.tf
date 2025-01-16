provider "yandex" {
  service_account_key = file("/home/bezumel/authorized_key.json")  # путь к вашему сервисному аккаунту
  cloud_id           = "b1g8tssboq6kq6qsl5pb"  # ID вашего облака
  folder_id          = "b1gaadh5jrnspg1gklri"   # ID вашей папки
}

