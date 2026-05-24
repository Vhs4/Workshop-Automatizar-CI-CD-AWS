---
name: feedback-s3-backend-bucket-name
description: S3 backend bucket name has account ID suffix — always read from existing stack versions.tf, not from ADR description
metadata:
  type: feedback
---

The actual S3 backend bucket name is `dvn-workshop-production-terraform-state-407295215751`, NOT `dvn-workshop-production-terraform-state`.

**Why:** ADR-0004 cited the bucket without the account ID suffix. The actual bucket (from ADR-0002 implementation) has the suffix appended for global uniqueness. Always confirm by reading an existing stack's `versions.tf` (e.g., `02-eks-stack-ai/versions.tf`) rather than trusting the ADR description.

**How to apply:** Before writing `backend "s3"` blocks in new stacks, read the bucket name from `dvn-workshop-terraform/02-eks-stack-ai/versions.tf` or `01-networking-stack-ai/versions.tf`.
