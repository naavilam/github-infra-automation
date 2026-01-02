output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "artifact_bucket" {
  value = aws_s3_bucket.lambda_artifacts.bucket
}

output "github_dispatcher_secret_arn" {
  value = aws_secretsmanager_secret.credentials.arn
}