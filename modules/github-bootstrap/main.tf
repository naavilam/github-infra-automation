terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.60"
    }
  }

  cloud {
    organization = "GitHub-Space"
    workspaces {
      name = "github-bootstrap"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      ManagedBy = "terraform"
      Owner     = "GitHub-Space"
    }
  }
}

provider "tfe" {}