variable "cors_origin" { type = string }
variable "component"   { type = string }

variable "artifact_bucket"        { type = string }

variable "github_app_id" {
  type = string
}

variable "github_installation_id" {
  type = string
}

variable "github_private_key_pem" {
  type      = string
  sensitive = true
}

variable "dispatch_shared_token" {
  type      = string
  sensitive = true
}

variable "github_owner" { 
    type = string 
}  

variable "github_repo"  { 
    type = string 
}