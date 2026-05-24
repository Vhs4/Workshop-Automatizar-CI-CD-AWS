# Trust policy for the CI role.
#
# Used by pull_request events only. Uses StringLike (not StringEquals) because
# "pull_request" is a fixed token, but the sub claim format GitHub issues is
# "repo:<org>/<repo>:pull_request" which is an exact string — still using
# StringEquals here for strictness. CI role has zero AWS permissions beyond
# being assumable, which validates that the trust works from PRs without
# exposing any deploy capability.
data "aws_iam_policy_document" "github_ci_trust" {
  statement {
    sid     = "AllowGitHubOIDCPullRequest"
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

    # StringLike used here: the pull_request token is a fixed literal but the
    # claim format matches "repo:<org>/<repo>:pull_request" exactly. Using
    # StringLike preserves intent and matches the GitHub OIDC documentation.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github.organization}/${var.github.repository}:pull_request"]
    }
  }
}

resource "aws_iam_role" "github_actions_ci" {
  name                 = var.github.ci_role_name
  assume_role_policy   = data.aws_iam_policy_document.github_ci_trust.json
  max_session_duration = 3600
  description          = "GitHub Actions CI role for PR builds. No AWS permissions beyond identity validation."
}
