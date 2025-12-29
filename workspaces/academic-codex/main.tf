terraform {
  cloud {
    organization = "GitHub-Space"
    workspaces { name = "Academic-Codex" }
  }

  required_providers {
    aws = { source = "hashicorp/aws",  version = "~> 5.0" }
    null = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

provider "aws" {

  default_tags {
    tags = {
      Namespace = var.name_prefix   # governança / agrupamento
      Component = var.component     # o app real
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
  dispatch_shared_secret = var.dispatch_shared_secret
  cors_origin            = var.cors_origin
  env                    = var.env
  name_prefix            = var.name_prefix
}

variable "cors_origin" { type = string }

variable "env"         { type = string }
variable "name_prefix" { type = string }
variable "component"   { type = string }

variable "github_app_id"          { type = string }
variable "github_installation_id" { type = string }

variable "github_private_key_pem" {
  type      = string
  sensitive = true
}

variable "dispatch_shared_secret" {
  type      = string
  sensitive = true
}