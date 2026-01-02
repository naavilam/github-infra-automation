
resource "aws_secretsmanager_secret" "credentials" {
  name = "github-dispatcher/credentials"
}
