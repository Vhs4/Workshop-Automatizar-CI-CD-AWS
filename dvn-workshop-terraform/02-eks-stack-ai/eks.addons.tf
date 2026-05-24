# eks-pod-identity-agent MUST be deployed first — other addons that use Pod Identity depend on it.
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = var.eks.addons.pod_identity_agent_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name = "${local.cluster_name}-addon-pod-identity-agent"
  }
}

# vpc-cni uses Pod Identity for IAM (via aws_eks_pod_identity_association below).
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = var.eks.addons.vpc_cni_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = var.eks.addons.enable_vpc_cni_prefix_delegation ? jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
    }
  }) : null

  depends_on = [
    aws_eks_node_group.this,
    aws_eks_addon.pod_identity_agent,
    aws_eks_pod_identity_association.vpc_cni,
  ]

  tags = {
    Name = "${local.cluster_name}-addon-vpc-cni"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = var.eks.addons.coredns_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.this]

  tags = {
    Name = "${local.cluster_name}-addon-coredns"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = var.eks.addons.kube_proxy_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.this]

  tags = {
    Name = "${local.cluster_name}-addon-kube-proxy"
  }
}

# Pod Identity association: binds the vpc-cni service account to the vpc_cni IAM role.
# The pod-identity-agent addon must be active before this association is effective.
resource "aws_eks_pod_identity_association" "vpc_cni" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-node"
  role_arn        = aws_iam_role.vpc_cni.arn

  depends_on = [aws_eks_addon.pod_identity_agent]

  tags = {
    Name = "${local.cluster_name}-vpc-cni-pod-identity-assoc"
  }
}
