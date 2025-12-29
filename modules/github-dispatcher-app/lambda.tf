locals {
  lambda_src = "${var.repo_root}/lambda/lambda_function.py"
}

# Gera o ZIP durante o PLAN/APPLY (sem depender de local-exec)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local.lambda_src
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "dispatcher" {
  function_name = "${var.component}-dispatcher"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.11"
  timeout       = 30

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      GITHUB_SECRET_ARN      = aws_secretsmanager_secret.credentials.arn
      DISPATCH_SHARED_SECRET = var.dispatch_shared_secret
      CORS_ORIGIN            = var.cors_origin
      USER_AGENT             = var.component
    }
  }

  depends_on = [
    aws_secretsmanager_secret_version.credentials
  ]
}
