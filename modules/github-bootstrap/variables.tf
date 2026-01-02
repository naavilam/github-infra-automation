variable "artifact_bucket" {
  type        = string
  description = "Nome do bucket S3 compartilhado para artifacts de Lambda/CodeBuild"
  default     = "github-space-artifacts"
}

variable "dispatch_shared_token" {
  type      = string
  sensitive = true
}

variable "cors_origin" { type = string }
variable "env"         { type = string }

variable "component" {
  description = "Prefixo global para nomes de recursos do bootstrap (ex: github-space)"
  type        = string
  default     = "github-space"
}

variable "tfc_org" {
  type    = string
  default = "GitHub-Space"
}

variable "remote_state_consumers" {
  type    = list(string)
  default = [
    "academic-codex",
    "high-energy",
    "quantum-computing",
    "quantum-materials",
  ]
}