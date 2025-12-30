locals {
  lambda_s3_key = "${var.component}/lambda.zip"
}

data "aws_s3_object" "lambda_zip" {
  count  = var.deploy_lambda ? 1 : 0
  bucket = aws_s3_bucket.lambda_artifacts.bucket
  key    = local.lambda_s3_key
}

resource "aws_lambda_function" "dispatcher" {
  count = var.deploy_lambda ? 1 : 0

  function_name = "${var.component}-dispatcher"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.11"
  timeout       = 30

  s3_bucket         = var.artifact_bucket
  s3_key            = var.lambda_zip_key
  s3_object_version = data.aws_s3_object.lambda_zip[0].version_id

  environment {
    variables = {
      GITHUB_SECRET_ARN      = aws_secretsmanager_secret.credentials.arn
      DISPATCH_SHARED_SECRET = var.dispatch_shared_secret
      CORS_ORIGIN            = var.cors_origin
      USER_AGENT             = var.component
    }
  }
}