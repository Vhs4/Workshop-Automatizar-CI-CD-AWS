# Trust policy for the deploy role.
#
# CRITICAL: StringEquals (not StringLike) for the sub claim on the deploy role.
# Using StringLike with a wildcard would allow any fork or branch to assume
# this role and gain ECR push + EKS kubectl access.
data "aws_iam_policy_document" "github_deploy_trust" {
  statement {
    sid     = "AllowGitHubOIDCMainBranch"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github.organization}/${var.github.repository}:ref:refs/heads/${var.github.deploy_branch}"]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name                 = var.github.deploy_role_name
  assume_role_policy   = data.aws_iam_policy_document.github_deploy_trust.json
  max_session_duration = 3600
  description          = "GitHub Actions deploy role for main branch. ECR push + EKS kubectl in namespace youtube-live."
}

# Policy 1: ECR GetAuthorizationToken
#
# This action is account-scoped and the AWS API requires Resource = "*".
# This is intentional and documented — there is no way to scope this to a
# specific repository. The actual push permissions are scoped to specific
# repository ARNs in the ecr-push policy below.
data "aws_iam_policy_document" "ecr_auth" {
  statement {
    sid    = "ECRGetAuthorizationToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    # tfsec:ignore:aws-iam-no-policy-wildcards - required by ECR API design
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecr_auth" {
  name   = "ecr-auth"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.ecr_auth.json
}

# Policy 2: ECR push — scoped to the 2 application repositories only.
data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid    = "ECRPushToAppRepositories"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:TagResource",
    ]
    resources = [
      for r in var.ecr_repository_names :
      "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${r}"
    ]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.ecr_push.json
}

# Policy 3: EKS DescribeCluster — required for aws eks update-kubeconfig.
# Scoped to the specific cluster ARN, not wildcard.
data "aws_iam_policy_document" "eks_describe" {
  statement {
    sid    = "EKSDescribeCluster"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster"
    ]
    resources = [local.eks_cluster_arn]
  }
}

resource "aws_iam_role_policy" "eks_describe" {
  name   = "eks-describe"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.eks_describe.json
}
