resource "aws_launch_template" "node" {
  name        = "${local.cluster_name}-node-lt"
  description = "Launch template for EKS managed node group - ${local.cluster_name}"

  # IMDSv2 required — blocks SSRF/escalation via IMDSv1
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_group.disk_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(local.common_tags, {
      Name = "${local.cluster_name}-node"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(local.common_tags, {
      Name = "${local.cluster_name}-node-volume"
    })
  }

  tags = {
    Name = "${local.cluster_name}-node-lt"
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.node_group.name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.private_subnet_ids

  # instance_types, disk_size, and ami_type are set here because launch_template
  # does not set the AMI directly — ami_type on the node group controls the AMI family.
  ami_type       = var.node_group.ami_type
  capacity_type  = var.node_group.capacity_type
  instance_types = var.node_group.instance_types

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    desired_size = var.node_group.desired_size
    min_size     = var.node_group.min_size
    max_size     = var.node_group.max_size
  }

  update_config {
    max_unavailable = var.node_group.max_unavailable
  }

  labels = var.node_group.labels

  dynamic "taint" {
    for_each = var.node_group.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_eks_worker_node_policy,
    aws_iam_role_policy_attachment.node_ec2_container_registry_pull_only,
    aws_iam_role_policy_attachment.node_ssm_managed_instance_core,
    aws_iam_role_policy_attachment.node_eks_cni_policy,
  ]

  tags = {
    Name = "${local.cluster_name}-${var.node_group.name}-ng"
  }
}
