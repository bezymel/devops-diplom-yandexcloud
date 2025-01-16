variable "storage_bucket_name" {
  description = "my-bucket-name"
  type        = string
}

variable "service_account_key" {
  description = "service_account_key"
  type        = string
}

variable "folder_id" {
  type        = string
  description = "folder_id"
}

variable "zone" {
  description = "Availability zone for the instances"
  type        = string
  default     = "ru-central1-b"
}

variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "subnet_id" {
  description = "ID of the subnet where the instances will be deployed"
  type        = string
}

### ssh vars

variable "security_group_id" {
  type        = string
  description = "ID of the security group to associate with the instances"
}

variable "ssh_key" {
  description = "The public ssh key"
  type        = string
  sensitive   = true
}
