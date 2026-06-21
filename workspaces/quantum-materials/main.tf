terraform {
  cloud {
    organization = "GitHub-Space"
    workspaces { name = "quantum-materials" }
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

  artifact_bucket        = local.artifact_bucket
  dispatch_shared_token  = var.dispatch_shared_token

  github_credentials    = var.github_credentials

  github_owner           = var.github_owner
  github_repo            = var.github_repo
}

data "terraform_remote_state" "bootstrap" {
  backend = "remote"
  config = {
    organization = "GitHub-Space"
    workspaces = { name = "github-bootstrap" }
  }
}

locals {
  artifact_bucket = data.terraform_remote_state.bootstrap.outputs.artifact_bucket
}

variable "cors_origin" { type = string }
variable "component"   { type = string }

variable "github_dispatcher_app_id"          { type = string }
variable "github_dispatcher_installation_id" { type = string }
variable "artifact_bucket"        { type = string }

variable "github_dispatcher_private_key_pem" {
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

variable "github_owner" { 
  type = string 
}  

variable "github_repo"  { 
  type = string 
}

variable "github_credentials" {
  type      = string
  sensitive = true
}