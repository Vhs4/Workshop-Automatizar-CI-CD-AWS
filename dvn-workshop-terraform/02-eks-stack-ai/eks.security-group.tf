resource "aws_security_group" "cluster_additional" {
  name        = "${local.cluster_name}-cluster-additional-sg"
  description = "Additional security group for the EKS cluster - managed by Terraform"
  vpc_id      = local.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-cluster-additional-sg"
  }
}
