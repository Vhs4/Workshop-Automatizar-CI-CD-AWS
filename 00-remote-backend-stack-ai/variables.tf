variable "aws_region" {
  description = "AWS region where the state backend bucket will be provisioned."
  type        = string
  nullable    = false
}

variable "project" {
  description = "Project-level settings shared across all resources in this stack."
  type = object({
    name        = string
    environment = string
  })
  nullable = false
}

variable "backend" {
  description = "Configuration for the Terraform remote backend S3 bucket."
  type = object({
    bucket_name_prefix                 = string
    noncurrent_version_expiration_days = number
    abort_incomplete_multipart_days    = number
    lock_file_expiration_days          = number
    force_destroy                      = bool
  })
  nullable = false
}
