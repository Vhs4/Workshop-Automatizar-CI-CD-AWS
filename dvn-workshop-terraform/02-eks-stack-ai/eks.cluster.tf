resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  version  = var.eks.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  enabled_cluster_log_types = var.eks.enabled_cluster_log_types

  # Disable self-managed addon bootstrapping; addons are managed explicitly via aws_eks_addon.
  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode = "API"
    # bootstrap_cluster_creator_admin_permissions is create-only — any post-create change
    # forces cluster replacement. Set to false (access managed via aws_eks_access_entry)
    # and ignore future drift to prevent accidental destroy+recreate.
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = local.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster_additional.id]
    endpoint_private_access = var.eks.endpoint_private_access
    endpoint_public_access  = var.eks.endpoint_public_access
    public_access_cidrs     = var.eks.endpoint_public_access_cidrs
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  lifecycle {
    # bootstrap_cluster_creator_admin_permissions is a create-only attribute.
    # Ignoring changes prevents Terraform from forcing cluster replacement on any drift.
    ignore_changes = [access_config[0].bootstrap_cluster_creator_admin_permissions]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_eks_cluster_policy,
    aws_cloudwatch_log_group.cluster,
  ]

  tags = {
    Name = local.cluster_name
  }
}
