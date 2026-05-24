output "eks_cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster API server."
  value       = aws_eks_cluster.this.endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data for the EKS cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "eks_cluster_oidc_issuer_url" {
  description = "The OIDC issuer URL for the EKS cluster (for IRSA if needed in future)."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "eks_cluster_version" {
  description = "The Kubernetes version of the EKS cluster."
  value       = aws_eks_cluster.this.version
}

output "eks_cluster_security_group_id" {
  description = "The ID of the cluster security group created and managed by EKS."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_iam_role_arn" {
  description = "The ARN of the IAM role used by the EKS control plane."
  value       = aws_iam_role.cluster.arn
}

output "eks_node_iam_role_arn" {
  description = "The ARN of the IAM role used by the EKS node group instances."
  value       = aws_iam_role.node.arn
}

output "eks_node_group_arn" {
  description = "The ARN of the EKS managed node group."
  value       = aws_eks_node_group.this.arn
}

output "eks_node_group_status" {
  description = "The current status of the EKS managed node group."
  value       = aws_eks_node_group.this.status
}

output "eks_kms_key_arn" {
  description = "The ARN of the KMS CMK used to encrypt EKS secrets and EBS volumes."
  value       = aws_kms_key.eks_secrets.arn
}

output "eks_log_group_name" {
  description = "The name of the CloudWatch log group for EKS control plane logs."
  value       = aws_cloudwatch_log_group.cluster.name
}

output "eks_kubeconfig_command" {
  description = "AWS CLI command to update the local kubeconfig for this cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}
