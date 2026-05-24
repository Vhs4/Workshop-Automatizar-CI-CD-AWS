---
name: ADR-0003 EKS Stack
description: EKS cluster stack in 02-eks-stack-ai/ rewritten 2026-05-24; t4g.small ARM, K8s 1.33, Pod Identity, Access Entries
type: project
---

Stack `02-eks-stack-ai` implements ADR-0003 (rewritten 2026-05-24): EKS 1.33, 2x t4g.small ARM ON_DEMAND, 4 managed addons,
Pod Identity for vpc-cni, Access Entries for admin IAM principals. All previous version files replaced.

**Why:** Workshop Kubernetes platform on VPC from stack 01. Four empirical constraints drove the rewrite:
(1) Account SCP blocks non-free-tier EC2 — t3.medium fails, only t4g.small is viable.
(2) K8s 1.31 in extended support ($0.60/hr) — 1.33 in standard ($0.10/hr).
(3) bootstrap_cluster_creator_admin_permissions is create-only — must use lifecycle.ignore_changes from day one.
(4) Non-ASCII in AWS API descriptions causes validation failures — use ASCII only in all resource descriptions.

**How to apply:** Stacks 00 (remote backend) and 01 (networking) must be deployed first. Then:
`/terraform-deploy 02-eks-stack-ai` or manually with `-var-file=envs/production.tfvars`.

Key implementation details for downstream stacks:
- S3 backend key: `eks/terraform.tfstate`
- Provider: `hashicorp/aws ~> 6.0` (resolved to 6.46.0)
- 14 outputs: cluster name/ARN/endpoint/CA(sensitive)/OIDC URL/version/SG ID, IAM roles ARNs, node group ARN/status, KMS key ARN, log group name, kubeconfig command
- networking_remote_state consumed via var (not hardcoded in main.tf) — values in envs/production.tfvars
- AMI type: AL2023_ARM_64_STANDARD — container images MUST be linux/arm64 or multi-arch
- No OIDC provider/IRSA — Pod Identity used instead (simpler, no public OIDC endpoint needed)
- authentication_mode = "API" (no aws-auth ConfigMap)
- bootstrap_self_managed_addons = false
- eks-pod-identity-agent addon deployed first, others depend on node group
- vpc-cni uses Pod Identity (aws_eks_pod_identity_association.vpc_cni, role: vpc_cni, SA: aws-node, ns: kube-system)
- AmazonEC2ContainerRegistryPullOnly on node role (more restrictive than ReadOnly)
- File layout: eks.cluster.tf / eks.iam.tf / eks.kms.tf / eks.cloudwatch.tf / eks.security-group.tf / eks.node-group.tf / eks.addons.tf / eks.access.tf

[[ADR-0001 Networking Stack]]
[[ADR-0002 Remote Backend Stack]]
