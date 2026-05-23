---
name: feedback-s3-inline-attributes-deprecated
description: S3 inline arguments in aws_s3_bucket are deprecated in provider v6 — always use standalone resources
metadata:
  type: feedback
---

Never use inline arguments inside `aws_s3_bucket` for versioning, encryption, lifecycle, policy, or ACL in provider v6.46.0+.

**Why:** These inline arguments are deprecated in provider v6. They cause plan drift and perpetual diffs. The correct approach is always separate standalone resources.

**How to apply:** Always write:
- `aws_s3_bucket_versioning` (not `versioning {}` block inside `aws_s3_bucket`)
- `aws_s3_bucket_server_side_encryption_configuration` (not `server_side_encryption_configuration {}`)
- `aws_s3_bucket_lifecycle_configuration` (not `lifecycle_rule {}`)
- `aws_s3_bucket_policy` (not `policy = ...` attribute)
- `aws_s3_bucket_public_access_block` (not inline)
- `aws_s3_bucket_ownership_controls` (not inline)

Also: `bucket_key_enabled` is at the `rule {}` level in `aws_s3_bucket_server_side_encryption_configuration`, NOT inside `apply_server_side_encryption_by_default {}`.
