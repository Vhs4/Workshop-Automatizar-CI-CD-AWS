# GitHub Actions OIDC provider.
#
# thumbprint_list is intentionally omitted: the AWS provider v6 documentation
# explicitly states that for GitHub, AWS relies on its own CA library for
# certificate validation, so any configured thumbprint is ignored. Omitting
# it avoids drift if GitHub rotates its certificate.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  lifecycle {
    prevent_destroy = true
  }
}
