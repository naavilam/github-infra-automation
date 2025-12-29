terraform {
  cloud {
    organization = "GitHub-Spaces"
    workspaces { name = "Academic-Codex" }
  }

  required_providers {
    aws = { source = "hashicorp/aws",  version = "~> 5.0" }
    null = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Namespace = var.name_prefix   # governança / agrupamento
      Component = var.component     # o app real
      Env       = var.env
      ManagedBy = "terraform"
      Owner     = "GitHub-Spaces"
    }
  }
}

module "app" {
  source = "../../modules/github-dispatcher-app"

  component              = var.component
  github_app_id          = var.github_app_id
  github_installation_id = var.github_installation_id
  github_private_key_pem = var.github_private_key_pem
  dispatch_shared_secret = var.dispatch_shared_secret
  cors_origin            = var.cors_origin
}