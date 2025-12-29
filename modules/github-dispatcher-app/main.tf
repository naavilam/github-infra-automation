terraform {
  cloud {
    organization = "GitHub-Spaces"
    workspaces {
      name = "Academic-Codex"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.name_prefix
      Owner     = "GitHub-Spaces"
      ManagedBy = "terraform"
      Env       = var.env
    }
  }
}