output "bucket_name" {
  description = "my-bucket-name"
  value       = yandex_storage_bucket.my_bucket.name
}

output "bucket_location" {
  description = "terraform/state"
  value       = yandex_storage_bucket.my_bucket.location
}
