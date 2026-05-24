resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.cluster_admins)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = {
    Name = "${local.cluster_name}-admin-access-entry"
  }
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = toset(var.cluster_admins)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}
