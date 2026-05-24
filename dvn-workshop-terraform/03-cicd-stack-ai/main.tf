provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = var.eks_remote_state.bucket
    key    = var.eks_remote_state.key
    region = var.eks_remote_state.region
  }
}

locals {
  eks_cluster_name = data.terraform_remote_state.eks.outputs.eks_cluster_name
  eks_cluster_arn  = data.terraform_remote_state.eks.outputs.eks_cluster_arn
}
