
resource "aws_secretsmanager_secret" "credentials" {
  name        = "github-dispatcher/credentials/${var.component}"
  description = "GitHub App credentials for ${var.component}"
}

resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id = aws_secretsmanager_secret.credentials.id

  secret_string = jsonencode({
    app_id          = var.github_app_id
    installation_id = var.github_installation_id
    private_key_pem = var.github_private_key_pem
  })
}