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

variable "my-bucket-encryption-key" {
  type    = string
  default = "abjdrrn2ov80f23m8j5n"
}

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
