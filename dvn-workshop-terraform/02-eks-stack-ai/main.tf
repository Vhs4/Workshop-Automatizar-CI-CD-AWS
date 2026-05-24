provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = var.networking_remote_state.bucket
    key    = var.networking_remote_state.key
    region = var.networking_remote_state.region
  }
}

locals {
  cluster_name       = var.eks.cluster_name
  vpc_id             = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
}
