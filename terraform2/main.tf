#СоздаeM сервисный аккаунт

resource "yandex_iam_service_account" "ww" {
  name = var.ww_name
  description = "Description of the service account."
}

#Добавляем права storage.admin

resource "yandex_resourcemanager_folder_iam_member" "ww-admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.ww.id}"
}

#Создаем ключ доступа к нашему хранилищу

resource "yandex_iam_service_account_static_access_key" "ww-static-key" {
  service_account_id = yandex_iam_service_account.ww.id
  description        = "static access key for object storage"
}



#Создаем VPC с подсетями в разных зонах доступности

resource "yandex_vpc_network" "my_vpc" {
  name = var.VPC_name
}

resource "yandex_vpc_subnet" "mysubnet-a" {
  name = "mysubnet-a"
  v4_cidr_blocks = ["10.5.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = var.yandex_vpc_network
}

resource "yandex_vpc_subnet" "mysubnet-b" {
  name = "mysubnet-b"
  v4_cidr_blocks = ["10.6.0.0/16"]
  zone           = "ru-central1-b"
  network_id     = var.yandex_vpc_network
}

resource "yandex_vpc_subnet" "mysubnet-d" {
  name = "mysubnet-d"
  v4_cidr_blocks = ["10.7.0.0/16"]
  zone           = "ru-central1-d"
  network_id     = var.yandex_vpc_network
}


#Конфиграция control-plane ноды

resource "yandex_compute_instance" "control-plane" {
  name            = var.control_plane_name
  zone            = "ru-central1-a"
  platform_id     = var.platform
  resources {
    cores         = var.control_plane_core
    memory        = var.control_plane_memory
    core_fraction = var.control_plane_core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.control_plane_disk_size
    }
  }

  scheduling_policy {
    preemptible = var.scheduling_policy
  }

  network_interface {
    subnet_id = var.mysubnet-a  # Используем первый элемент списка
    nat       = var.nat                      # Включите NAT, если это необходимо
  }

  metadata = {
    user-data = <<-EOF
      #cloud-config
      ssh_pwauth: true
      users:
        - name: bezumel
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh-authorized-keys:
            - ${var.ssh_public_key}
          passwd: ${var.bezumel_password}  # Задайте пароль для пользователя
        - name: root
          passwd: ${var.root_password}  # Задайте пароль для root
      runcmd:
        - echo 'bezumel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/bezumel
        - chmod 440 /etc/sudoers.d/bezumel
    EOF
  }
}

#Конфигурация worker нод:

resource "yandex_compute_instance" "worker_1" {
  name            = "worker-node-1"
  platform_id     = var.worker_platform
  zone            = "ru-central1-b"
  resources {
    cores         = var.worker_cores
    memory        = var.worker_memory
    core_fraction = var.worker_core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.worker_disk_size
    }
  }

  scheduling_policy {
    preemptible = var.scheduling_policy
  }

  network_interface {
    subnet_id = var.mysubnet-b
    nat       = var.nat
  }

  metadata = {
    user-data = <<-EOF
      #cloud-config
      ssh_pwauth: true
      users:
        - name: bezumel
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh-authorized-keys:
            - ${var.ssh_public_key}
          passwd: ${var.bezumel_password}  # Задайте пароль для пользователя
      runcmd:
        - echo 'bezumel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/bezumel
        - chmod 440 /etc/sudoers.d/bezumel
    EOF
  }
}

resource "yandex_compute_instance" "worker_2" {
  name            = "worker-node-2"
  platform_id     = var.worker_platform2
  zone            = "ru-central1-d"
  resources {
    cores         = var.worker_cores
    memory        = var.worker_memory
    core_fraction = var.worker_core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.worker_disk_size
    }
  }

  scheduling_policy {
    preemptible = var.scheduling_policy
  }

  network_interface {
    subnet_id = var.mysubnet-d
    nat       = var.nat
  }

  metadata = {
    user-data = <<-EOF
      #cloud-config
      ssh_pwauth: true
      users:
        - name: bezumel
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh-authorized-keys:
            - ${var.ssh_public_key}
          passwd: ${var.bezumel_password}  # Задайте пароль для пользователя
      runcmd:
        - echo 'bezumel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/bezumel
        - chmod 440 /etc/sudoers.d/bezumel
    EOF
  }
}
