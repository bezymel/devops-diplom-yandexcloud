variable "storage_bucket_name" {
  description = "my-bucket-name"
  type        = string
}

variable "service_account_key" {
  type        = string
  default     = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwtMJ2/yRkek3uvsxNRBoqdqflG3UeJ3dGvkqeoY06Q5GnhdQZ/mRUMFvtMWcMv0EYLZtP4JrY+Y3qbh/FyE5Ij60alRrgRYQ0IB4C/ErVeAPK675Ng5gNHowU0ImGMUyKMGQTNDMhC2ZKXPWX6rFEWX6rFEFPbMfFGAaEbrI+yevFyIFLusO2HriRNoQLA9TMIXG59mW0i/i3nd2fHGhcBz/zraFsr37Vz6+JtTQFgeOOs52x2f2qSHZ9AO4CvbnMU1AxC7EWH/1PyjDjdsHI7YOaFr9ot/y8h+g3nPrcIAZOKaFA00iHwa/AI1q8N8mIwj2HOCg864KiiOrO7u2GVRZDNhwIDAQAB"
  description = "Path to the JSON key file for the service account"
}

variable "folder_id" {
  type        = string
  default     = "b1gaadh5jrnspg1gklri"
  description = "folder_id"
}

variable "zone" {
  description = "Availability zone for the instances"
  type        = string
  default     = "ru-central1-b"
}
