variable "aws_region"  { type = string, default = "us-east-2" }
variable "env"         { type = string, default = "prod" }

# Governança: pode ser "github-spaces" ou "academic-codex" (seu critério)
variable "name_prefix" {
  type        = string
  description = "Namespace/owner lógico (tags, governança)."
  default     = "academic-codex"
}

# Nome do app real que vira prefixo dos recursos
variable "component" {
  type        = string
  description = "Nome do componente/app (ex: academic-codex-app)."
}

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

variable "cors_origin" {
  type    = string
  default = "https://naavilam.github.io"
}