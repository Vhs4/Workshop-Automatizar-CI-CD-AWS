# EKS Access Entry for the GitHub Actions deploy role.
# type=STANDARD grants the IAM role a Kubernetes identity (not a node or add-on role).
resource "aws_eks_access_entry" "github_deploy" {
  cluster_name  = local.eks_cluster_name
  principal_arn = aws_iam_role.github_actions_deploy.arn
  type          = "STANDARD"
}

# EKS Access Policy Association: AmazonEKSEditPolicy scoped to namespace youtube-live.
#
# AmazonEKSEditPolicy grants create/delete/patch/update on deployments (apps apiGroup),
# which covers:
#   - kubectl set image deployment/<x> app=<uri> -n youtube-live
#   - kubectl rollout undo deployment/<x> -n youtube-live
#   - kubectl rollout status deployment/<x> -n youtube-live
#
# ARN format: arn:aws:eks::aws:cluster-access-policy/<PolicyName>
# The partition in this ARN is always "aws" (AWS-managed policy, not account-scoped).
resource "aws_eks_access_policy_association" "github_deploy_edit" {
  cluster_name  = local.eks_cluster_name
  principal_arn = aws_iam_role.github_actions_deploy.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.eks_deploy_namespace]
  }

  depends_on = [aws_eks_access_entry.github_deploy]
}
