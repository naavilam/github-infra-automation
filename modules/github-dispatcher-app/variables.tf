variable "cors_origin" { type = string }
variable "repo_root" { type = string }

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