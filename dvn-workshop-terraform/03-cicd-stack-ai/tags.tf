locals {
  common_tags = {
    Environment = var.project.environment
    Project     = var.project.name
    ManagedBy   = "terraform"
    Stack       = "03-cicd"
    ADR         = "ADR-0004"
  }
}
