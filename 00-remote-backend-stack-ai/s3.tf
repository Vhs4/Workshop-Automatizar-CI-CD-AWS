locals {
  bucket_name = "${var.backend.bucket_name_prefix}-${data.aws_caller_identity.current.account_id}-${var.project.environment}"
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.backend.force_destroy

  tags = {
    Name = local.bucket_name
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
