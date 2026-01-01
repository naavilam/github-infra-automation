provider "aws" {
  profile = "github"
  region = "us-east-2"

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Owner     = "GitHub-Space"
    }
  }
}