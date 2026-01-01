provider "aws" {

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Owner     = "GitHub-Space"
    }
  }
}

terraform { 
  cloud { 
    
    organization = "GitHub-Space" 

    workspaces { 
      name = "github-space-bootstrap" 
    } 
  } 
}
