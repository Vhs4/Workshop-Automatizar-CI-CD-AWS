resource "aws_s3_bucket_lifecycle_configuration" "this" {
  # Versioning must be enabled before lifecycle rules that touch noncurrent versions
  depends_on = [aws_s3_bucket_versioning.this]

  bucket = aws_s3_bucket.this.id

  # Rule 1: Expire noncurrent versions of state files after N days
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days           = var.backend.noncurrent_version_expiration_days
      newer_noncurrent_versions = 5
    }
  }

  # Rule 2: Abort incomplete multipart uploads after N days
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.backend.abort_incomplete_multipart_days
    }
  }

  # Rule 3: Expire orphaned .tflock files left by crashed Terraform processes
  rule {
    id     = "expire-orphaned-tflock-files"
    status = "Enabled"

    filter {
      prefix = ".tflock"
    }

    expiration {
      days = var.backend.lock_file_expiration_days
    }
  }
}
