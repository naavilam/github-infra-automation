locals {
  lambda_zip_key = "${var.component}/lambda.zip"
}

data "aws_s3_object" "lambda_zip" {
  count  = var.deploy_lambda ? 1 : 0
  bucket = var.artifact_bucket
  key    = local.lambda_zip_key
}

resource "aws_lambda_function" "dispatcher" {
  count = var.deploy_lambda ? 1 : 0

  function_name = "${var.component}-dispatcher"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.11"
  timeout       = 30

  s3_bucket         = var.artifact_bucket
  s3_key            = local.lambda_zip_key
  s3_object_version = var.deploy_lambda ? data.aws_s3_object.lambda_zip[0].version_id : null

  environment {
    variables = {
      GITHUB_SECRET_ARN      = var.github_secret_arn
      dispatch_shared_token = var.dispatch_shared_token
      CORS_ORIGIN            = var.cors_origin
      USER_AGENT             = var.component
    }
  }
}