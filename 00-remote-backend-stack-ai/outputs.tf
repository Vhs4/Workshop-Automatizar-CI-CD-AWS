output "state_bucket_id" {
  description = "Name (ID) of the S3 bucket storing Terraform state files."
  value       = aws_s3_bucket.this.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket storing Terraform state files."
  value       = aws_s3_bucket.this.arn
}

output "state_bucket_region" {
  description = "AWS region where the state bucket resides."
  value       = aws_s3_bucket.this.region
}

output "backend_config_snippet" {
  description = "Ready-to-copy backend configuration block for downstream stacks. Replace <STACK_NAME> with the stack's key path segment."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.this.id}"
        key          = "stacks/<STACK_NAME>/terraform.tfstate"
        region       = "${aws_s3_bucket.this.region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
