output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_ci_role_arn" {
  description = "ARN of the IAM role used by GitHub Actions for PR builds (no AWS permissions)."
  value       = aws_iam_role.github_actions_ci.arn
}

output "github_actions_deploy_role_arn" {
  description = "ARN of the IAM role used by GitHub Actions for main-branch deploys. Set as AWS_DEPLOY_ROLE_ARN variable in GitHub repo settings."
  value       = aws_iam_role.github_actions_deploy.arn
}

output "github_repo_fullname" {
  description = "Full GitHub repository name (org/repo) used in trust policies."
  value       = "${var.github.organization}/${var.github.repository}"
}

output "ecr_registry" {
  description = "ECR registry base URL for this account and region."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "eks_cluster_name" {
  description = "EKS cluster name sourced from remote state (for reference in workflows)."
  value       = local.eks_cluster_name
}
