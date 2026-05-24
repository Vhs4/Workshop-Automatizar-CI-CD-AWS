resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.eks.log_retention_days

  tags = {
    Name = "${local.cluster_name}-control-plane-logs"
  }
}
