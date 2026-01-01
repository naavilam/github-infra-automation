variable "artifact_bucket" {
  type        = string
  description = "Nome do bucket S3 compartilhado para artifacts de Lambda/CodeBuild"
  default     = "github-space-artifacts"
}

variable "dispatch_shared_secret" {
  type      = string
  sensitive = true
}
