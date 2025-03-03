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

Промежуточный итог https://github.com/bezymel/devops-diplom-yandexcloud/tree/main/terraform

4. Создайте VPC с подсетями в разных зонах доступности.

  * Создаем VPC с подсетями в разных зонах доступности
```
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
```

  * Указываем переменные:

```
### vpc vars

variable "VPC_name" {
  type        = string
  default     = "my-vpc"
}

```

Выполняем команду:

```
terraform apply
```

![image](https://github.com/user-attachments/assets/2aa62ca0-c772-44e3-a6a0-bd519c586518)
![image](https://github.com/user-attachments/assets/573d01bb-8a89-4df5-aa37-06b56d57ed49)
![image](https://github.com/user-attachments/assets/8d2aaf11-a048-4ca7-95cd-54c4854124c7)
![image](https://github.com/user-attachments/assets/b43fce3e-745d-452b-bd4d-c9029a35d649)
![image](https://github.com/user-attachments/assets/f6b2c73b-4475-4ea2-bd07-1ac11edd59ed)



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

Промежуточный итог https://github.com/bezymel/devops-diplom-yandexcloud/tree/main/terraform1

---
### Создание Kubernetes кластера

На этом этапе необходимо создать [Kubernetes](https://kubernetes.io/ru/docs/concepts/overview/what-is-kubernetes/) кластер на базе предварительно созданной инфраструктуры.   Требуется обеспечить доступ к ресурсам из Интернета.

Это можно сделать двумя способами:

Рекомендуемый вариант: самостоятельная установка Kubernetes кластера.
а. При помощи Terraform подготовить как минимум 3 виртуальных машины Compute Cloud для создания Kubernetes-кластера. Тип виртуальной машины следует выбрать самостоятельно с учётом требовании к производительности и стоимости. Если в дальнейшем поймете, что необходимо сменить тип инстанса, используйте Terraform для внесения изменений.
В целях экономии выделенного бюджета и с учетом ресурсоемкости создадим кластер из одной control-plane ноды и двух worker нод.

  * Конфиграция control-plane ноды:

```
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

variable "mysubnet-a" {
  description = "Пароль для пользователя bezumel"
  type        = string
  default     = "e9bc77gbvrrl1fhngoer"
}
```

   * Конфигурация worker нод:

```
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
```

   * Переменные для worker нод:

```
### worker nodes vars

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

variable "bezumel_password" {
  description = "Пароль для пользователя bezumel"
  type        = string
  sensitive   = true
}

variable "root_password" {
  description = "Пароль для root пользователя"
  type        = string
  sensitive   = true
}

variable "mysubnet-b" {
  description = "Пароль для пользователя bezumel"
  type        = string
  default     = "e2log9l8u5hprmrkip8n"
}

variable "mysubnet-d" {
  description = "Пароль для пользователя bezumel"
  type        = string
  default     = "fl8c1m3119ohhc4mjjl9"
}


variable "worker_platform2" {
  type        = string
  default     = "standard-v2"
}
```

main.tf
```
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
```

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

### vpc vars

variable "VPC_name" {
  type        = string
  default     = "my-vpc"
}

#SSH-key

variable "ssh_public_key" {
  description = "The public SSH key for accessing the instance."
  type        = string
}

variable "yandex_vpc_network" {
  type    = string
  default = "enpg8eb9p7oonpva34g3"
}

variable "regional-k8s-sg" {
  type    = string
  default = "enperr0p1ei20fl0cm9h"
}

variable "my-bucket-encryption-key" {
  type    = string
  default = "abjdrrn2ov80f23m8j5n"
}

```

![image](https://github.com/user-attachments/assets/1a061c0f-39fb-4239-81eb-7ba6e8502025)



б. Подготовить ansible конфигурации, можно воспользоваться, например Kubespray

Скачиваем репозиторий с Kubespray
```
git clone https://github.com/kubernetes-sigs/kubespray
```
Устанавливаем зависимости
```
python3.10 -m pip install --upgrade pip
pip3 install -r requirements.txt
```
Добавьте Kubespray в файл requirements.yml
```
collections:
- name: https://github.com/kubernetes-sigs/kubespray
  type: git
  version: master # use the appropriate tag or branch for the version you need
 ``` 
Установите свою коллекцию
```
ansible-galaxy install -r requirements.yml
```

Копируем шаблон с inventory файлом
```
cp -rfp /home/bezumel/Diplom1/terraform/kubespray/inventory/sample /home/bezumel/Diplom1/terraform/mycluster
```

Корректируем файл inventory.ini, где прописываем актуальные ip адреса виртуальных машин, развернутых в предвдущих пунктах, в качестве CRI будем использовать containerd, а запуск etcd будет осущуствляться на мастере.
```
# ## Configure 'ip' variable to bind kubernetes services on a
# ## different ip than the default iface
# ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
[all]
node1 ansible_host=130.193.48.10 ansible_user=bezumel ansible_ssh_private_key_file=~/.ssh/id_rsa  # ip==10.3.0.1  etcd_member_name=etcd1
node2 ansible_host=84.201.178.228  ansible_user=bezumel ansible_ssh_private_key_file=~/.ssh/id_rsa  # ip==10.3.0.2 etcd_member_name=etcd2
node3 ansible_host=158.160.142.207  ansible_user=bezumel ansible_ssh_private_key_file=~/.ssh/id_rsa  # ip==10.3.0.3 etcd_member_name=etcd3
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

в. Задеплоить Kubernetes на подготовленные ранее инстансы, в случае нехватки каких-либо ресурсов вы всегда можете создать их при помощи Terraform.
```
ansible-playbook -i /home/bezumel/Diplom1/terraform/mycluster/sample/inventory.ini cluster.yml -b -v
```
![image](https://github.com/user-attachments/assets/3e59df46-dd84-4355-ba1b-05941d0dd72b)

  
Ожидаемый результат:

1. Работоспособный Kubernetes кластер.
   
   * Подключаемся к control-plane ноде
```
ssh -l bezumel 130.193.48.10
```
   * Проверяем, что кластер состоит из одной control-plane ноды и двух worker нод
```
kubectl get nodes
```
![image](https://github.com/user-attachments/assets/1b02f927-d801-4369-a61a-ce2a90d9860e)

    
2. В файле `~/.kube/config` находятся данные для доступа к кластеру.
   ![image](https://github.com/user-attachments/assets/97c88747-c2ee-4ebd-b510-f2720765b1de)


3. Команда `kubectl get pods --all-namespaces` отрабатывает без ошибок.
   ![image](https://github.com/user-attachments/assets/6f5ba005-5999-4e53-99a4-86c50ce8dbd6)

В качестве промежуточного итога прилагаю terraform манифест и файлы, необходимые для создания инфраструктуры, описанной выше:
https://github.com/bezymel/devops-diplom-yandexcloud/tree/main/terraform2

---
### Создание тестового приложения

Для перехода к следующему этапу необходимо подготовить тестовое приложение, эмулирующее основное приложение разрабатываемое вашей компанией.

Способ подготовки:

1. Рекомендуемый вариант:  
   а. Создайте отдельный git репозиторий с простым nginx конфигом, который будет отдавать статические данные.  
   б. Подготовьте Dockerfile для создания образа приложения.  

  * Создан репозиторий [nginx-static](https://github.com/bezymel/nginx-static/tree/main)

  * Далее копируем репозиторий на виртуальную машину в одноименную директорию
    
```
git init
git clone https://github.com/bezymel/nginx-static.git
```

  * Создаем внутри проекта директорию [static](https://github.com/bezymel/nginx-static/tree/main/static) и в ней указываем конфигурацию файла основной стартовой страницы index.html и styles.css, созданного для улучшения внешнего вида нашей веб-страницы. Также создаем директорию images для хранения там фоновой картинки.

б. Подготовьте Dockerfile для создания образа приложения.

  * Переходим в корневую директорию и создаем Dockerfile следующей конфигурации
    
```
FROM nginx:latest

COPY ./static /usr/share/nginx/html

EXPOSE 80
```

   * Сохраняем изменения в ветке main нашего репозитория:
     
```
git add .
git commit -m "first commit"
git push https://github.com/bezymel/nginx-static.git main
```

Далее авторизовываемся на DockerHub и в консоли и собираем docker образ

```
docker login
docker build -t bezumelll/nginx-static:latest .
```

![image](https://github.com/user-attachments/assets/a7a69946-32d3-49cf-a238-1034251bdb13)

И размещаем его в нашем хранилище на DockerHub

```
docker push bezumelll/nginx-static:latest
```

![image](https://github.com/user-attachments/assets/d7877975-0dc0-43b2-9e35-541d3452d71c)
![image](https://github.com/user-attachments/assets/52d59e77-bb6a-4745-af6b-0e722bcceb1d)

Ожидаемый результат:

1. Git репозиторий с тестовым приложением и Dockerfile.
2. Регистри с собранным docker image. В качестве регистри может быть DockerHub или [Yandex Container Registry](https://cloud.yandex.ru/services/container-registry), созданный также с помощью terraform.

---
### Подготовка cистемы мониторинга и деплой приложения

Уже должны быть готовы конфигурации для автоматического создания облачной инфраструктуры и поднятия Kubernetes кластера.  
Теперь необходимо подготовить конфигурационные файлы для настройки нашего Kubernetes кластера.

Цель:
1. Задеплоить в кластер [prometheus](https://prometheus.io/), [grafana](https://grafana.com/), [alertmanager](https://github.com/prometheus/alertmanager), [экспортер](https://github.com/prometheus/node_exporter) основных метрик Kubernetes.

   * Выполним установку вышеуказанных мониторингов через helm. Сначала установим helm на control-plane ноду
```
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```
   * Создаем отдельное простанство имен для мониторинга
```
kubectl create namespace monitoring
```
   * Добавляем репозиторий helm c prometheus
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```
   * Устанавливаем kube-prometheus-stack (установка Prometheus, Grafana, Alertmanager, node-exporter и kube-state-metrics)
```
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```
   * Проверяем, что все поры работают нормально
```
kubectl get pods -n monitoring
```

![image](https://github.com/user-attachments/assets/b3ba49f2-9b47-4c60-8ee8-50d9eaef2c04)


   * Получаем пароль от Grafana
```
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
   * Настраиваем доступ к Grafana по внешнему ip адресу, для чего создаем файл values.yml
```
grafana:
  service:
    type: NodePort
    nodePort: 32000
```

   * Обновляем helm чарт
```
helm upgrade prometheus prometheus-community/kube-prometheus-stack -n monitoring -f values.yml
```

![image](https://github.com/user-attachments/assets/28fbe7f0-f930-435f-b1c6-92c9a5282c4b)

   * Далее настраиваем необходимые метрики, так для k8s кластера. Для простоты воспользуемся готовым дашбордом из того, что предлагает Grafana - ID 315
   * Проверем наличие новых дашбордов

![image](https://github.com/user-attachments/assets/16a01929-7ab9-4748-b58c-ab346ee4132f)

Видим, что из кластера поступают данные, но в пока мы не деплоили наше приложение, мониторинг не слишком информативен ввиду отсутствия рабочей нагрузки

![image](https://github.com/user-attachments/assets/253724e0-364e-45aa-89eb-dfac16133722)

  
3. Задеплоить тестовое приложение, например, [nginx](https://www.nginx.com/) сервер отдающий статическую страницу.

   * Cоздаем деплой nginx-deployment.yml, куда прописываем следующую конфигурацию
     
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-static
  labels:
    app: nginx-static
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-static
  template:
    metadata:
      labels:
        app: nginx-static
    spec:
      containers:
        - name: nginx
          image: bezumelll/nginx-static:latest
          ports:
            - containerPort: 80
```

   * Также нам необходим сервис nginx-service.yml

```
piVersion: v1
kind: Service
metadata:
  name: nginx-static
  labels:
    app: nginx-static
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
      nodePort: 32002
  selector:
    app: nginx-static
```

Применяем изменения и проверяем результат

```
kubectl apply -f nginx-deployment.yml
kubectl apply -f nginx-service.yml
kubectl get pods -l app=nginx-static
```
![image](https://github.com/user-attachments/assets/3404c8c9-9a2c-4939-a104-c904966cc67a)
![image](https://github.com/user-attachments/assets/5c1e5ed2-195c-4ea6-a626-2c3e877736ce)



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

   * Копируем репозиторий
```
git clone https://github.com/scriptcamp/kubernetes-jenkins
```

   * Создаем новое пространство имен, чтобы было проще отслеживать работу подов и сервисов
```
kubectl create namespace devops-tools
```

   * Создаем сервисный аккаунт для Jenkins, оставляя без изменений файл serviceAccount.yaml из скачанного репозитория
```
kubectl apply -f serviceAccount.yaml
```

   * Указываем в deployment.yaml тома постоянного хранения данных (настройки пользователя, пайплайны и т.д., так как наш кластер использует ради экономии прерываемые виртуальные машины).
```
volumeMounts:
            - name: jenkins-data
              mountPath: /var/jenkins_home
            - name: docker-socket
              mountPath: /var/run/docker.sock
            - name: docker-bin
              mountPath: /tmp/docker-bin

volumes:
        - name: jenkins-data
          persistentVolumeClaim:
            claimName: jenkins-pvc
        - name: docker-socket
          hostPath:
            path: /var/run/docker.sock
        - name: docker-bin
          emptyDir: {}
```

   * И соответственно создаем требуемый persistent volume
     
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/var/jenkins_home"
А также persistent volume claim

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: devops-tools
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
Для корректной работы необходимо создать директорию /var/jenkins_home на всех нодах нашего кластера, для чего необходимо в deployment.yaml добавить инитконтейнер, устанавливающий docker и git

initContainers:
        - name: install-docker-git
          image: ubuntu:22.04
          command:
          - sh
          - -c
          - |
            apt-get update && \
            apt-get install -y curl gnupg && \
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
            apt-get update && \
            apt-get install -y docker-ce-cli && \
            mkdir -p /tmp/docker-bin && \
            cp /usr/bin/docker /tmp/docker-bin/docker
            apt-get install -y git
          volumeMounts:
          - name: docker-bin
            mountPath: /tmp/docker-bin
          - name: jenkins-data
            mountPath: /var/jenkins_home
          - name: docker-socket
            mountPath: /var/run/docker.sock
```

   * Применяем изменения и проверяем успешный запуск Jenkins
     
```
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
kubectl apply -f deployment.yaml
kubectl get deployments -n devops-tools
kubectl get pods -n devops-tools
```

![image](https://github.com/user-attachments/assets/1031627f-96dc-4abb-a968-cbca204d51df)

   * Далее создаем соответствующий сервис. Незначительно корректируем дефортный файл service.yaml из скачанного репозитория, указав nodePort: 32001, так как дефолтный порт 32000 уже занят мониторингом (Grafana), а на порту 32002 работает наш сервер nginx.

   * Запускаем сервис
     
```
kubectl apply -f service.yaml
```

   * Для первого входа через веб-интерфейс определяем пароль
     
```
kubectl logs jenkins-cf789dc4d-l2v56 --namespace=devops-tools
```

![image](https://github.com/user-attachments/assets/bc82387b-9353-4802-b3d9-14550ad6bcfc)

   * Далее необходимо настроить pipeline. Сборка и отправка в регистр docker-image по условиям задания должна осуществляться при любом коммите в репозитории.
Для этого переходим в репозиторий и создаем webhook в веб-интерфейсе GitHub

![image](https://github.com/user-attachments/assets/ba6c42ef-701a-493f-88b3-5bafab0bb90a)

   * Входим в графический интерфейс и устанавливаем плагины, предлагаемые Jenkins. Далее осуществляем стандартную настройку Jenkins, указывая логин, пароль и электронную почту в соответствующих пунктах меню. Далее копирую ссылку url для быстрого доступа (для упрощения задания ip адреса виртуальных машин, участвующих в проекте сделаны статическими).

```
http://84.201.178.228:32001/
```

![image](https://github.com/user-attachments/assets/a59a2f65-a2af-40d4-8001-44ba366604ac)

   * Также необходимо настроить Docker Credentials в веб-интерфейсе Jenkins.
     
![image](https://github.com/user-attachments/assets/95f1081e-3966-47e7-aa6c-f2b317a3f957)

   * Далее настраиваем агенты для сборки на основе Kubernetes pod. Для этого сначала установим плагин Kubernetes для Jenkins, далее создаем новое облако Kubernetes, в настройках прописываем пространство имен devops-tools, в котором развернут под с Jenkins и также через графический интерфейс тестируем соединение с кластером.

![image](https://github.com/user-attachments/assets/1b90bf5d-d332-4ab6-95bb-c7d03f717690)

   * Убедившись в наличии подключения, добавляем шаблон пода, который будет являться нашим сборочным агентом. Задаем название jenkins-agent, указываем пространство имен и image inbound-agent

![image](https://github.com/user-attachments/assets/c6bae01a-84c4-460a-853f-27fbd58e2519)

Подробная инструкция по созданию и настройке агента доступна по ссылке. Поскольку после публикации статьи в Jenkins прошел ряд обновлений, то не вся информация в ней актуальна (например названия плагинов), но в целом описанный метод является рабочим (на период сентября 2024 года).

   * Также для автоматизации нашего проекта необходима организация доступа через токен к DockerHub, Получаем токен в личном кабинете на https://app.docker.com

![image](https://github.com/user-attachments/assets/652b7f2e-8705-4274-b961-e0d559f5a815)

   * Сохраняем токен в credentials

![image](https://github.com/user-attachments/assets/3bc588dc-b3b2-43a2-a757-8fed3e7ced39)

   * После того как предварительная настройка Jenkins произведена, создадим pipeline для нашего проекта
```
pipeline {
    agent any  

    environment {
        DOCKER_HUB_REPO = 'bezumelll/nginx-static'
        DOCKER_CREDENTIALS_ID = '40d43344-1e51-45be-82bf-bc26c42bce12'  // ID учетных данных Docker Hub в Jenkins
        KUBECONFIG_CREDENTIALS_ID = '0065dfd6-1b94-44d5-9d55-ff7d34d8be22'  // ID учетных данных для подключения к Kubernetes в Jenkins
    }

    stages {
        stage('Checkout') {
            steps {
                // Получение кода из GitHub
                git branch: 'main', url: 'https://github.com/bezymel/nginx-static.git'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    // Получение текущего тега, если есть
                    def tag = env.GIT_TAG_NAME ?: 'latest'
                    // Сборка Docker-образа
                    sh "docker build -t ${DOCKER_HUB_REPO}:${tag} ."
                }
            }
        }
        
        stage('Push to Docker Hub') {
           steps {
             withCredentials([string(credentialsId: 'docker_hub_pat', variable: 'DOCKER_HUB_PAT')]) {
               sh """
               echo $DOCKER_HUB_PAT | docker login -u bezumelll --password-stdin
               docker push bezumelll/nginx-static::latest
               """
            }
        }
    }
        
        stage('Deploy to Kubernetes') {
            when {
                tag "v*" // Деплой выполняется только при создании тега
            }
            steps {
                script {
                    withCredentials([file(credentialsId: KUBECONFIG_CREDENTIALS_ID, variable: 'KUBECONFIG')]) {
                        def tag = env.GIT_TAG_NAME ?: 'latest'
                        // Применение конфигурации деплоя в Kubernetes
                        sh """
                        kubectl set image deployment/nginx-static-deployment nginx-static=${DOCKER_HUB_REPO}:${tag}
                        kubectl rollout status deployment/nginx-static-deployment
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
```

Также для автоматизации нашего проекта необходима организация доступа через токен к DockerHub, Получаем токен в личном кабинете на https://app.docker.com

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

