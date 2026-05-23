---
name: project-adr0002-bootstrap
description: ADR-0002 remote backend bootstrap completed — bucket name, state keys, migration status
metadata:
  type: project
---

ADR-0002 implemented and deployed on 2026-05-23. S3 remote backend with native locking is live.

**Bucket (dev):** `tf-state-workshop-cicd-aws-407295215751-dev` (us-east-1)
**State key pattern:** `stacks/<NN-stack-name>/terraform.tfstate`
**Currently migrated stacks:**
- `stacks/00-remote-backend/terraform.tfstate` — stack-00 self-state
- `stacks/01-networking/terraform.tfstate` — networking VPC stack (24 resources, vpc-0bc9d100781646980)

**Why:** Remote backend is the prerequisite for multi-user collaboration and CI/CD pipelines. Chosen Terraform native locking (use_lockfile=true) over DynamoDB — no DynamoDB needed, aligns with HashiCorp roadmap (dynamodb_table is deprecated in 1.11+).

**How to apply:** When provisioning new stacks, add backend block using the snippet from `state_bucket_id` output. Use key `stacks/<stack-name>/terraform.tfstate`. Staging/production buckets not yet created — only dev bucket exists.

Related: [[project-adr0001-networking]], [[feedback-s3-inline-attributes-deprecated]]
