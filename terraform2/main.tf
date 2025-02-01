#Конфиграция control-plane ноды

resource "yandex_compute_instance" "control-plane" {
  name            = var.control_plane_name
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
    subnet_id = yandex_vpc_subnet.public_subnet[0].id
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
        - name: root
          passwd: ${var.root_password}  # Задайте пароль для root
      runcmd:
        - echo 'bezumel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/bezumel
        - chmod 440 /etc/sudoers.d/bezumel
    EOF
  }
}

#Конфигурация worker нод:

resource "yandex_compute_instance" "worker" {
  count           = var.worker_count
  name            = "worker-node-${count.index + 1}"
  platform_id     = var.worker_platform
  zone            = var.public_subnet_zones[count.index]
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
    subnet_id = yandex_vpc_subnet.public_subnet[count.index].id
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

