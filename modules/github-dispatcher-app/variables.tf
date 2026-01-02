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

variable "github_secret_arn" {
  type      = string
  sensitive = true
}

variable "dispatch_shared_token" {
  type      = string
}

variable "deploy_lambda" {
  type        = bool
  description = "Quando false, não recria/atualiza a Lambda (bootstrap de infra)."
  default     = false
}

# variable "app_name" { type = string }            # ex: "high-energy"
# variable "aws_region" { type = string }

# variable "artifact_bucket" { type = string }     # ex: "github-space-artifacts"
# variable "lambda_zip_key" { type = string }      # ex: "high-energy/lambda.zip"

# variable "github_secret_arn" { type = string }   # secret com app_id/installation_id/private_key_pem
# variable "dispatch_shared_token" {
#   type      = string
#   sensitive = true
# }

# variable "cors_origin" { type = string  default = "*" }
# variable "user_agent"  { type = string  default = "github-dispatcher" }

# controle de bootstrap
# variable "deploy_lambda" { type = bool default = false }
