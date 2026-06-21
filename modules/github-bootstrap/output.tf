output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "artifact_bucket" {
  value = aws_s3_bucket.lambda_artifacts.bucket
}