# Дипломный практикум в Yandex.Cloud
  * [Цели:](#цели)
  * [Этапы выполнения:](#этапы-выполнения)
     * [Создание облачной инфраструктуры](#создание-облачной-инфраструктуры)
     * [Создание Kubernetes кластера](#создание-kubernetes-кластера)
     * [Создание тестового приложения](#создание-тестового-приложения)
     * [Подготовка cистемы мониторинга и деплой приложения](#подготовка-cистемы-мониторинга-и-деплой-приложения)
     * [Установка и настройка CI/CD](#установка-и-настройка-cicd)
  * [Что необходимо для сдачи задания?](#что-необходимо-для-сдачи-задания)
  * [Как правильно задавать вопросы дипломному руководителю?](#как-правильно-задавать-вопросы-дипломному-руководителю)

**Перед началом работы над дипломным заданием изучите [Инструкция по экономии облачных ресурсов](https://github.com/netology-code/devops-materials/blob/master/cloudwork.MD).**

---
## Цели:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.

---
## Этапы выполнения:


### Создание облачной инфраструктуры

Для начала необходимо подготовить облачную инфраструктуру в ЯО при помощи [Terraform](https://www.terraform.io/).

Особенности выполнения:

- Бюджет купона ограничен, что следует иметь в виду при проектировании инфраструктуры и использовании ресурсов;
Для облачного k8s используйте региональный мастер(неотказоустойчивый). Для self-hosted k8s минимизируйте ресурсы ВМ и долю ЦПУ. В обоих вариантах используйте прерываемые ВМ для worker nodes.

Предварительная подготовка к установке и запуску Kubernetes кластера.

1. Создайте сервисный аккаунт, который будет в дальнейшем использоваться Terraform для работы с инфраструктурой с необходимыми и достаточными правами. Не стоит использовать права суперпользователя

  * Создаем сервисный аккаунт, добавляем права storage.admin и создаем ключ доступа к нашему хранилищу:

main.tf
```
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
```

   * Создаем файл providers.tf
```
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }

  required_version = ">=1.4"
  }

provider "yandex" {
  token = var.token
  cloud_id = var.cloud_id
  folder_id = var.folder_id
  zone = var.default_zone
}

```

   * Чтобы получить ключ доступа и привытный ключ, суонфигурированный вышеуказанным кодом - подготовим возможность вывода значений ключей в терминал, для чего создадим файл outputs.tf

outputs.tf
```
output "s3_access_key" {
  description = "Yandex Cloud S3 access key"
  value       = yandex_iam_service_account_static_access_key.ww-static-key.access_key
  sensitive   = true
}

output "s3_secret_key" {
  description = "Yandex Cloud S3 secret key"
  value       = yandex_iam_service_account_static_access_key.ww-static-key.secret_key
  sensitive   = true
}
```
   * Так же опишем переменные в файле variables.tf 

variables.tf 
```
### cloud vars

variable "folder_id" {
  type        = string
  description = "folder_id"
}

variable "default_zone" {
  description = "Availability zone for the instances"
  type        = string
  default     = "ru-central1-a"
}

variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "ww_name" {
  description = "Service account name"
  type        = string
  default     = "ww"
}
```
   * Файл для значений переменных personal.auto.tfvars

personal.auto.tfvars
```
token  =  "https://yandex.cloud/ru/docs/iam/concepts/authorization/oauth-token"
cloud_id  = "https://console.yandex.cloud/cloud/"
folder_id = "https://console.yandex.cloud/folders/"
```
   * Применяем изменения и узнаем значения ключей
```
terraform plan                     #Показывает план изменений
terraform apply                    #Применяет изменения
terraform output s3_access_key     #Выводит значение ключа
terraform output s3_secret_key     #Выводит значение ключа
```

![image](https://github.com/user-attachments/assets/466a6cb8-d74a-4816-a4cf-01ac9699bdad)
![image](https://github.com/user-attachments/assets/6b18f3a2-88bf-41a8-8a3f-ac3fd25f5e3c)
![image](https://github.com/user-attachments/assets/95ab38c0-ce01-45b7-bca4-0299cc4d686f)

  
2. Подготовьте [backend](https://www.terraform.io/docs/language/settings/backends/index.html) для Terraform:  
   а. Рекомендуемый вариант: S3 bucket в созданном ЯО аккаунте(создание бакета через TF)

  * Узнаем значения ключей командами что описаны выше и прописываем их в файл providers.tf

providers.tf
```
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
```
   * Теперь создаем сам бакет, потому что нельзя настроить удаленное хранение состояния конфигурации терраформ в бакете, не создав при этом сам бакет:

```
yc storage bucket create --name diplom-project-nemcev
```
![image](https://github.com/user-attachments/assets/7700c454-6054-4067-a553-0366048d9d05)

Инициализируем инфраструктуру:

```
terraform init
```
![image](https://github.com/user-attachments/assets/c10eb8ae-88aa-433a-9707-3572df909f64)
![image](https://github.com/user-attachments/assets/fbe6a0dc-4cad-4059-aadc-0bd6915212a9)


   
3. Создайте конфигурацию Terrafrom, используя созданный бакет ранее как бекенд для хранения стейт файла. Конфигурации Terraform для создания сервисного аккаунта и бакета и основной инфраструктуры следует сохранить в разных папках.

* Создаем отдельную папку и помещаем все файлы туда, для разделения. Что бы в случае выполнения команды terraform destroy не удаляло наш сервисный аккаунт и бэкенд.
  
![image](https://github.com/user-attachments/assets/5ed9dc8c-43df-4aac-95dd-9be5b085c91c)


4. Создайте VPC с подсетями в разных зонах доступности.

  * Создаем VPC с подсетями в разных зонах доступности
```
#Создаем VPC с подсетями в разных зонах доступности

resource "yandex_vpc_network" "my_vpc" {
  name = var.VPC_name
}

resource "yandex_vpc_subnet" "public_subnet" {
  count = length(var.public_subnet_zones)
  name  = "${var.public_subnet_name}-${var.public_subnet_zones[count.index]}"
  v4_cidr_blocks = [
    cidrsubnet(var.public_v4_cidr_blocks[0], 4, count.index)
  ]
  zone       = var.public_subnet_zones[count.index]
  network_id = yandex_vpc_network.my_vpc.id
}
```

  * Указываем переменные:

```
### vpc vars

variable "VPC_name" {
  type        = string
  default     = "my-vpc"
}

### subnet vars

variable "public_subnet_name" {
  type        = string
  default     = "public"
}

variable "public_v4_cidr_blocks" {
  type        = list(string)
  default     = ["192.168.10.0/24"]
}

variable "subnet_zone" {
  type        = string
  default     = "ru-central1"
}

variable "public_subnet_zones" {
  type    = list(string)
  default = ["ru-central1-a", "ru-central1-b",  "ru-central1-d"]
}
```

Выполняем команду:

```
terraform apply
```

![image](https://github.com/user-attachments/assets/6515cf78-8555-4203-90c7-950360f5c2a3)
![image](https://github.com/user-attachments/assets/7e2bad67-bab9-4b45-a7b3-e8ed7d304527)
![image](https://github.com/user-attachments/assets/8d2aaf11-a048-4ca7-95cd-54c4854124c7)
![image](https://github.com/user-attachments/assets/d6c9a20d-a76e-4593-ae61-df62462ffd20)
![image](https://github.com/user-attachments/assets/3b7e1975-8b3f-49a4-8e14-9146b29555d0)


Выполняем команду:

```
terraform destroy
```

5. Убедитесь, что теперь вы можете выполнить команды `terraform destroy` и `terraform apply` без дополнительных ручных действий.

При выполнении команды terraform destroy удаляются все вычислительные ресурсы, кроме нашего бакета и загруженного в него terraform.tfstate, а также созданной нами сети my-vpc (ожидаемый результат).
 
7. В случае использования [Terraform Cloud](https://app.terraform.io/) в качестве [backend](https://www.terraform.io/docs/language/settings/backends/index.html) убедитесь, что применение изменений успешно проходит, используя web-интерфейс Terraform cloud.

Ожидаемые результаты:

1. Terraform сконфигурирован и создание инфраструктуры посредством Terraform возможно без дополнительных ручных действий, стейт основной конфигурации сохраняется в бакете или Terraform Cloud
2. Полученная конфигурация инфраструктуры является предварительной, поэтому в ходе дальнейшего выполнения задания возможны изменения.

---
### Создание Kubernetes кластера

На этом этапе необходимо создать [Kubernetes](https://kubernetes.io/ru/docs/concepts/overview/what-is-kubernetes/) кластер на базе предварительно созданной инфраструктуры.   Требуется обеспечить доступ к ресурсам из Интернета.

Это можно сделать двумя способами:

1. Рекомендуемый вариант: самостоятельная установка Kubernetes кластера.  
   а. При помощи Terraform подготовить как минимум 3 виртуальных машины Compute Cloud для создания Kubernetes-кластера. Тип виртуальной машины следует выбрать самостоятельно с учётом требовании к производительности и стоимости. Если в дальнейшем поймете, что необходимо сменить тип инстанса, используйте Terraform для внесения изменений.

  * Конфиграция control-plane ноды:

```
#Конфиграция control-plane ноды

resource "yandex_vpc_subnet" "public_subnet" {
  count = length(var.public_subnet_zones)
  name  = "${var.public_subnet_name}-${var.public_subnet_zones[count.index]}"
  v4_cidr_blocks = [
    cidrsubnet(var.public_v4_cidr_blocks[0], 4, count.index)
  ]
  zone       = var.public_subnet_zones[count.index]
  network_id = yandex_vpc_network.my_vpc.id
}

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
    user-data = "${file("/home/bezumel/Diplom1/terraform/cloud-init.yaml")}"
 }
}
```

   * Переменные для control-plane ноды:

```
### control-plane node vars

variable "control_plane_name" {
  type        = string
  default     = "control-plane"
}

variable "platform" {
  type        = string
  default     = "standard-v1"
}

variable "control_plane_core" {
  type        = number
  default     = "4"
}

variable "control_plane_memory" {
  type        = number
  default     = "8"
}

variable "control_plane_core_fraction" {
  description = "guaranteed vCPU, for yandex cloud - 20, 50 or 100 "
  type        = number
  default     = "20"
}

variable "control_plane_disk_size" {
  type        = number
  default     = "50"
}

variable "image_id" {
  type        = string
  default     = "fd893ak78u3rh37q3ekn"
}

variable "scheduling_policy" {
  type        = bool
  default     = "true"
}
```

   * Конфигурация worker нод:

```
#Конфигурация worker нод:

resource "yandex_compute_instance" "worker" {
  count           = var.worker_count
  name            = "worker-node-${count.index + 1}"
  platform_id     = var.worker_platform
  zone = var.public_subnet_zones[count.index]
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
    user-data = "${file("/home/bezumel/Diplom1/terraform/cloud-init.yaml")}"
 }
}
```

   * Переменные для worker нод:

```
### worker nodes vars

variable "worker_count" {
  type        = number
  default     = "2"
}

variable "worker_platform" {
  type        = string
  default     = "standard-v1"
}

variable "worker_cores" {
  type        = number
  default     = "4"
}

variable "worker_memory" {
  type        = number
  default     = "2"
}

variable "worker_core_fraction" {
  description = "guaranteed vCPU, for yandex cloud - 20, 50 or 100 "
  type        = number
  default     = "20"
}

variable "worker_disk_size" {
  type        = number
  default     = "50"
}

variable "nat" {
  type        = bool
  default     = "true"
}
```

   * Для всех виртуальных машин используется cloud-init.yaml следующей конфигурации:
```
#cloud-config
users:
  - name: bezumel
    ssh_authorized_keys:
      - ssh-rsa <public_key>
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
package_update: true
package_upgrade: true
packages:
  - nginx
  - nano
  - software-properties-common
runcmd:
  - mkdir -p /home/bezumel/.ssh
  - chown -R bezumel:bezumel /home/bezumel/.ssh
  - chmod 700 /home/bezumel/.ssh
  - sudo add-apt-repository ppa:deadsnakes/ppa -y
  - sudo apt-get update
```
  * Применяем изменения

```
terrafrom plan
terraform apply
```

![image](https://github.com/user-attachments/assets/88e8e358-c5f7-4ce9-a08c-924d14cd5414)
![image](https://github.com/user-attachments/assets/b94ee2d3-69ed-4e06-b7ec-23720f5b8a24)



   б. Подготовить [ansible](https://www.ansible.com/) конфигурации, можно воспользоваться, например [Kubespray](https://kubernetes.io/docs/setup/production-environment/tools/kubespray/)  

   * Скачиваем репозиторий с Kubespray
```
git clone https://github.com/kubernetes-sigs/kubespray
```
   * Устанавливаем зависимости
```
python3.10 -m pip install --upgrade pip
pip3 install -r requirements.txt
```
   * Копируем шаблон с inventory файлом
```
cp -rfp /home/bezumel/Diplom1/terraform/kubespray/inventory/sample/ /home/bezumel/Diplom1/terraform/mycluster/
```
  * Корректируем файл inventory.ini, где прописываем актуальные ip адреса виртуальных машин, развернутых в предвдущих пунктах, в качестве CRI будем использовать containerd, а запуск etcd будет осущуствляться на мастере.
```
# ## Configure 'ip' variable to bind kubernetes services on a
# ## different ip than the default iface
# ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
[all]
node1 ansible_host=89.169.140.191 ansible_user=bezumel ansible_ssh_private_key_file=~/.ssh/id_rsa  # ip=192.168.10.9  etcd_member_name=etcd1
node2 ansible_host=158.160.38.2  ansible_user=bezumel ansible_ssh_private_key_file=~/.ssh/id_rsa  # ip=192.168.10.4 etcd_member_name=etcd2
node3 ansible_host=158.160.64.246  ansible_user=bezumel ansible_ssh_private_key_file=~/.ssh/id_rsa  # ip=192.168.10.28 etcd_member_name=etcd3
# node4 ansible_host=95.54.0.15   # ip=10.3.0.4 etcd_member_name=etcd4
# node5 ansible_host=95.54.0.16   # ip=10.3.0.5 etcd_member_name=etcd5
# node6 ansible_host=95.54.0.17   # ip=10.3.0.6 etcd_member_name=etcd6

# ## configure a bastion host if your nodes are not directly reachable
# [bastion]
# bastion ansible_host=x.x.x.x ansible_user=some_user

[kube_control_plane]
node1
# node2
# node3

[etcd]
 node1
# node2
# node3

[kube_node]
node2
node3
# node4
# node5
# node6

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr
```

Создаем файл cluster.yml

```
---
- hosts: all
  become: true
  become_user: root
  tasks:
    - name: Update apt cache and install required packages # Обновление кеша APT и установка необходимых пакетов
      apt:
        update_cache: yes
        name:
          - git
          - python3
          - python3-pip
          - curl
          - docker.io
          - containerd
        state: present



    - name: Enable and start Docker # Включение и запуск Docker
      systemd:
        name: docker
        enabled: yes
        state: started



    - name: Create custom inventory directory # Создание директории
      file:
        path: ~/diplom
        state: directory



    - name: Clone kubespray repo # Клонирование репозитория Kubespray
      git:
        repo: https://github.com/kubernetes-sigs/kubespray.git
        dest: ~/diplom
        version: 'master' 
        force: yes  # Если хотите перезаписать существующие изменения



    - name: Create custom inventory directory # Создание директории
      file:
        path: ~/mycluster
        state: directory



    - name: Copy inventory sample to customized inventory # Копирование образца инвентаря
      copy:
        src: ~/diplom/inventory/
        dest: ~/mycluster/
        remote_src: yes
        mode: '0755'



    - name: Configure inventory for hosts # Настройка инвентаря для хостов
      become: yes
      lineinfile:
        path: ~/mycluster/sample/inventory.ini
        regexp: '^  {{ item.key }}'
        line: "{{ item.key }}: {{ item.value }}"

      loop: 
        - { key: 'node1', value: 'ansible_host=89.169.140.191 ansible_user=bezumel ansible_ssh_private_key_file=~/.ssh/id_rsa etcd_member_name=etcd1' }
        - { key: 'node2', value: 'ansible_host=158.160.38.2  ansible_user=bezumel ansible_ssh_private_key_file=~/.ssh/id_rsa etcd_member_name=etcd2' }
        - { key: 'node3', value: 'ansible_host=158.160.64.246  ansible_user=bezumel ansible_ssh_private_key_file=~/.ssh/id_rsa etcd_member_name=etcd3' }



    - name: Install Kubernetes dependencies # Установка зависимостей Kubernetes
      apt:
        name:
          - kubelet
          - kubeadm
          - kubectl
        state: present
        update_cache: yes



    - name: Add Kubernetes apt key # Добавление GPG ключа Kubernetes
      apt_key:
        url: https://packages.cloud.google.com/apt/doc/apt-key.gpg
        state: present



    - name: Add Kubernetes repository # Добавление репозитория Kubernetes
      apt_repository:
        repo: "deb https://apt.kubernetes.io/ kubernetes-xenial main"
        state: present



    - name: Mark Kubernetes packages to hold # Пометка пакетов Kubernetes как заблокированных
      command: apt-mark hold kubelet kubeadm kubectl



    - name: Initialize Kubernetes cluster # Инициализация кластера Kubernetes
      command: kubeadm init --pod-network-cidr=192.168.0.0/16
      when: inventory_hostname == 'node1'
      register: kubeadm_init_result
      ignore_errors: yes



    - name: Set kubeconfig for user # Настройка kubeconfig для пользователя
      shell: |
        mkdir -p $HOME/.kube
        cp /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config
      when: inventory_hostname == 'node1' and kubeadm_init_result is succeeded



    - name: Install Calico network plugin # Установка плагина сети Calico
      command: kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
      when: inventory_hostname == 'node1' and kubeadm_init_result is succeeded



    - name: Join worker nodes to the cluster # Присоединение рабочих узлов к кластеру
      command: >
        kubeadm join {{ hostvars['node1']['ansible_default_ipv4']['address'] }}:6443 --token {{ kubeadm_init_result.stdout_lines[0] }} --discovery-token-ca-cert-hash sha256:{{ kubeadm_init_result.stdout_lines[1] }}
      when: inventory_hostname != 'node1'

```

   в. Задеплоить Kubernetes на подготовленные ранее инстансы, в случае нехватки каких-либо ресурсов вы всегда можете создать их при помощи Terraform.
```  
bezumel@compute:~/Diplom1/terraform/mycluster$ ansible-playbook -i /home/bezumel/Diplom1/terraform/mycluster/sample/inventory.ini cluster.yml -b -v
```
```
bezumel@compute:~/Diplom1/terraform/mycluster$ ansible-playbook -i /home/bezumel/Diplom1/terraform/mycluster/sample/inventory.ini cluster.yml -b -v
No config file found; using defaults

PLAY [all] ********************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ********************************************************************************************************************************************************************************************
fatal: [node3]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: bezumel@158.160.87.118: Permission denied (publickey,password).", "unreachable": true}
fatal: [node1]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: bezumel@89.169.142.213: Permission denied (publickey,password).", "unreachable": true}
fatal: [node2]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: bezumel@89.169.152.76: Permission denied (publickey,password).", "unreachable": true}

PLAY RECAP ********************************************************************************************************************************************************************************************************
node1                      : ok=0    changed=0    unreachable=1    failed=0    skipped=0    rescued=0    ignored=0   
node2                      : ok=0    changed=0    unreachable=1    failed=0    skipped=0    rescued=0    ignored=0   
node3                      : ok=0    changed=0    unreachable=1    failed=0    skipped=0    rescued=0    ignored=0   
```

  
3. Альтернативный вариант: воспользуйтесь сервисом [Yandex Managed Service for Kubernetes](https://cloud.yandex.ru/services/managed-kubernetes)  
  а. С помощью terraform resource для [kubernetes](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_cluster) создать **региональный** мастер kubernetes с размещением нод в разных 3 подсетях      
  б. С помощью terraform resource для [kubernetes node group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_node_group)
  
Ожидаемый результат:

1. Работоспособный Kubernetes кластер.
2. В файле `~/.kube/config` находятся данные для доступа к кластеру.
3. Команда `kubectl get pods --all-namespaces` отрабатывает без ошибок.

---
### Создание тестового приложения

Для перехода к следующему этапу необходимо подготовить тестовое приложение, эмулирующее основное приложение разрабатываемое вашей компанией.

Способ подготовки:

1. Рекомендуемый вариант:  
   а. Создайте отдельный git репозиторий с простым nginx конфигом, который будет отдавать статические данные.  
   б. Подготовьте Dockerfile для создания образа приложения.  
2. Альтернативный вариант:  
   а. Используйте любой другой код, главное, чтобы был самостоятельно создан Dockerfile.

Ожидаемый результат:

1. Git репозиторий с тестовым приложением и Dockerfile.
2. Регистри с собранным docker image. В качестве регистри может быть DockerHub или [Yandex Container Registry](https://cloud.yandex.ru/services/container-registry), созданный также с помощью terraform.

---
### Подготовка cистемы мониторинга и деплой приложения

Уже должны быть готовы конфигурации для автоматического создания облачной инфраструктуры и поднятия Kubernetes кластера.  
Теперь необходимо подготовить конфигурационные файлы для настройки нашего Kubernetes кластера.

Цель:
1. Задеплоить в кластер [prometheus](https://prometheus.io/), [grafana](https://grafana.com/), [alertmanager](https://github.com/prometheus/alertmanager), [экспортер](https://github.com/prometheus/node_exporter) основных метрик Kubernetes.
2. Задеплоить тестовое приложение, например, [nginx](https://www.nginx.com/) сервер отдающий статическую страницу.

Способ выполнения:
1. Воспользоваться пакетом [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus), который уже включает в себя [Kubernetes оператор](https://operatorhub.io/) для [grafana](https://grafana.com/), [prometheus](https://prometheus.io/), [alertmanager](https://github.com/prometheus/alertmanager) и [node_exporter](https://github.com/prometheus/node_exporter). Альтернативный вариант - использовать набор helm чартов от [bitnami](https://github.com/bitnami/charts/tree/main/bitnami).

2. Если на первом этапе вы не воспользовались [Terraform Cloud](https://app.terraform.io/), то задеплойте и настройте в кластере [atlantis](https://www.runatlantis.io/) для отслеживания изменений инфраструктуры. Альтернативный вариант 3 задания: вместо Terraform Cloud или atlantis настройте на автоматический запуск и применение конфигурации terraform из вашего git-репозитория в выбранной вами CI-CD системе при любом комите в main ветку. Предоставьте скриншоты работы пайплайна из CI/CD системы.

Ожидаемый результат:
1. Git репозиторий с конфигурационными файлами для настройки Kubernetes.
2. Http доступ на 80 порту к web интерфейсу grafana.
3. Дашборды в grafana отображающие состояние Kubernetes кластера.
4. Http доступ на 80 порту к тестовому приложению.
---
### Установка и настройка CI/CD

Осталось настроить ci/cd систему для автоматической сборки docker image и деплоя приложения при изменении кода.

Цель:

1. Автоматическая сборка docker образа при коммите в репозиторий с тестовым приложением.
2. Автоматический деплой нового docker образа.

Можно использовать [teamcity](https://www.jetbrains.com/ru-ru/teamcity/), [jenkins](https://www.jenkins.io/), [GitLab CI](https://about.gitlab.com/stages-devops-lifecycle/continuous-integration/) или GitHub Actions.

Ожидаемый результат:

1. Интерфейс ci/cd сервиса доступен по http.
2. При любом коммите в репозиторие с тестовым приложением происходит сборка и отправка в регистр Docker образа.
3. При создании тега (например, v1.0.0) происходит сборка и отправка с соответствующим label в регистри, а также деплой соответствующего Docker образа в кластер Kubernetes.

---
## Что необходимо для сдачи задания?

1. Репозиторий с конфигурационными файлами Terraform и готовность продемонстрировать создание всех ресурсов с нуля.
2. Пример pull request с комментариями созданными atlantis'ом или снимки экрана из Terraform Cloud или вашего CI-CD-terraform pipeline.
3. Репозиторий с конфигурацией ansible, если был выбран способ создания Kubernetes кластера при помощи ansible.
4. Репозиторий с Dockerfile тестового приложения и ссылка на собранный docker image.
5. Репозиторий с конфигурацией Kubernetes кластера.
6. Ссылка на тестовое приложение и веб интерфейс Grafana с данными доступа.
7. Все репозитории рекомендуется хранить на одном ресурсе (github, gitlab)

