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

variable "dispatch_shared_secret" {
  type      = string
  sensitive = true
}

variable "deploy_lambda" {
  type        = bool
  description = "Quando false, não cria/atualiza a Lambda (bootstrap de infra)."
  default     = true
}
variable "lambda_zip_key" {
  type = string
}