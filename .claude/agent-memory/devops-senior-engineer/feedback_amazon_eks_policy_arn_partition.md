---
name: feedback-amazon-eks-policy-arn-partition
description: AWS-managed EKS access policies use literal 'aws' partition in ARN — do NOT use data.aws_partition.current.partition for them
metadata:
  type: feedback
---

Use `"arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"` as a literal string, NOT `"arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/..."`.

**Why:** AWS-managed EKS cluster access policies are account-independent and always in the `aws` partition. The `aws` in the ARN is the partition of the policy itself (always `aws`), not your account's partition. Using `data.aws_partition` would be correct for account-scoped resources (ECR repos, EKS cluster ARN, etc.) but is wrong here.

**How to apply:** When writing `aws_eks_access_policy_association.policy_arn`, always use the literal ARN. For account-scoped resources like ECR repos and EKS cluster ARNs, continue using `data.aws_partition.current.partition`.
