variable "cors_origin" { type = string }
variable "component"   { type = string }

variable "artifact_bucket"        { type = string }

variable "github_credentials" {
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