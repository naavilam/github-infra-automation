terraform {
  cloud {
    organization = "GitHub-Space"
    workspaces { name = "github-gateway" }
  }

  required_providers {
    aws = { source = "hashicorp/aws",  version = "~> 5.0" }
    null = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

variable "cors_origin" { type = string }