##############################################################################
# Cluster IAM role — assumed by eks.amazonaws.com
##############################################################################

resource "aws_iam_role" "cluster" {
  name        = "${local.cluster_name}-cluster-role"
  description = "IAM role for EKS control plane"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name = "${local.cluster_name}-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_eks_cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

##############################################################################
# Node IAM role — assumed by ec2.amazonaws.com
##############################################################################

resource "aws_iam_role" "node" {
  name        = "${local.cluster_name}-node-role"
  description = "IAM role for EKS managed node group instances"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.cluster_name}-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "node_eks_worker_node_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ec2_container_registry_pull_only" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm_managed_instance_core" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# vpc-cni requires CNI policy on the node role when not using Pod Identity exclusively;
# keeping it here ensures bootstrapping works even before the Pod Identity addon is active.
resource "aws_iam_role_policy_attachment" "node_eks_cni_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

##############################################################################
# VPC CNI Pod Identity role — assumed by pods.eks.amazonaws.com
##############################################################################

resource "aws_iam_role" "vpc_cni" {
  name        = "${local.cluster_name}-vpc-cni-pod-identity-role"
  description = "IAM role for vpc-cni addon via EKS Pod Identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name = "${local.cluster_name}-vpc-cni-pod-identity-role"
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni_eks_cni_policy" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}
