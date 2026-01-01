terraform {
  cloud {
    organization = "GitHub-Space"
    workspaces { name = "academic-codex" }
  }

  required_providers {
    aws = { source = "hashicorp/aws",  version = "~> 5.0" }
    null = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "aws" {

  default_tags {
    tags = {
      Namespace = var.component
      Component = var.component
      Env       = var.env
      ManagedBy = "terraform"
      Owner     = "GitHub-Space"
    }
  }
}

module "app" {
  source = "../../modules/github-dispatcher-app"

  component              = var.component
  github_app_id          = var.github_app_id
  github_installation_id = var.github_installation_id
  github_private_key_pem = var.github_private_key_pem
  cors_origin            = var.cors_origin
  env                    = var.env
  artifact_bucket        = var.artifact_bucket
  dispatch_shared_token  = var.dispatch_shared_token
  deploy_lambda          = var.deploy_lambda
}

variable "cors_origin" { type = string }
variable "env"         { type = string }
variable "component"   { type = string }

variable "github_app_id"          { type = string }
variable "github_installation_id" { type = string }
variable "artifact_bucket"        { type = string }

variable "github_private_key_pem" {
  type      = string
  sensitive = true
}

output "dispatch_url" {
  value = module.app.dispatch_url
}

variable "deploy_lambda" {
  type        = bool
  description = "Quando false, não cria/atualiza a Lambda (bootstrap de infra)."
}

variable "dispatch_shared_token" {
  type      = string
  sensitive = true
}

