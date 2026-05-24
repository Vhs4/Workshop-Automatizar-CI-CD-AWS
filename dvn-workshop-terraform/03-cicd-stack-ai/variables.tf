variable "aws_region" {
  description = "AWS region for the CI/CD stack."
  type        = string
  nullable    = false
}

variable "project" {
  description = "Project identification used for naming and tagging."
  type = object({
    name        = string
    environment = string
  })
  nullable = false
}

variable "eks_remote_state" {
  description = "Remote state config for the EKS stack outputs."
  type = object({
    bucket = string
    key    = string
    region = string
  })
  nullable = false
}

variable "github" {
  description = "GitHub OIDC and repository configuration."
  type = object({
    organization     = string
    repository       = string
    deploy_branch    = string
    ci_role_name     = string
    deploy_role_name = string
  })
  nullable = false
}

variable "ecr_repository_names" {
  description = "ECR repositories the deploy role is allowed to push to."
  type        = list(string)
  nullable    = false
}

variable "eks_deploy_namespace" {
  description = "Kubernetes namespace where the deploy role can act."
  type        = string
  nullable    = false
}
