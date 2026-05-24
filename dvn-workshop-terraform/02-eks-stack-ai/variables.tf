variable "aws_region" {
  description = "AWS region where all resources will be provisioned."
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

variable "networking_remote_state" {
  description = "Remote state configuration for the networking stack outputs."
  type = object({
    bucket = string
    key    = string
    region = string
  })
  nullable = false
}

variable "eks" {
  description = "EKS cluster configuration."
  type = object({
    cluster_name                 = string
    kubernetes_version           = string
    endpoint_private_access      = bool
    endpoint_public_access       = bool
    endpoint_public_access_cidrs = list(string)
    enabled_cluster_log_types    = list(string)
    log_retention_days           = number
    kms_deletion_window_days     = number
    addons = object({
      vpc_cni_version                  = string
      coredns_version                  = string
      kube_proxy_version               = string
      pod_identity_agent_version       = string
      enable_vpc_cni_prefix_delegation = bool
    })
  })
  nullable = false
}

variable "node_group" {
  description = "Managed node group configuration."
  type = object({
    name            = string
    instance_types  = list(string)
    capacity_type   = string
    ami_type        = string
    disk_size_gb    = number
    desired_size    = number
    min_size        = number
    max_size        = number
    max_unavailable = number
    labels          = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  })
  nullable = false
}

variable "cluster_admins" {
  description = "List of IAM principal ARNs that receive AmazonEKSClusterAdminPolicy via Access Entries."
  type        = list(string)
  nullable    = false
}
