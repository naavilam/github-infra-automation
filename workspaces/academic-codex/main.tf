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
      ManagedBy = "terraform"
      Owner     = "GitHub-Space"
    }
  }
}

module "app" {
  source = "../../modules/github-dispatcher-app"

  component              = var.component
  cors_origin            = var.cors_origin

  artifact_bucket        = var.artifact_bucket
  dispatch_shared_token  = var.dispatch_shared_token

  github_app_id          = var.github_app_id
  github_installation_id = var.github_installation_id
  github_private_key_pem = var.github_private_key_pem
}

variable "cors_origin" { type = string }
variable "component"   { type = string }

variable "github_app_id"          { type = string }
variable "github_installation_id" { type = string }
variable "artifact_bucket"        { type = string }

variable "github_private_key_pem" {
  type      = string
  sensitive = true
}

variable "dispatch_shared_token" {
  type      = string
  sensitive = true
}

output "dispatcher_invoke_arn" {
  value = module.app.dispatcher_invoke_arn
}

output "dispatcher_function_name" {
  value = module.app.dispatcher_function_name
}
