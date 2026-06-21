locals {
  lambda_zip_key = "dispatcher/lambda.zip"
}

data "aws_s3_object" "lambda_zip" {
  bucket = var.artifact_bucket
  key    = local.lambda_zip_key
}

resource "aws_lambda_function" "dispatcher" {

  function_name = "${var.component}-dispatcher"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.11"
  timeout       = 30

  s3_bucket         = var.artifact_bucket
  s3_key            = local.lambda_zip_key
  s3_object_version = data.aws_s3_object.lambda_zip.version_id

  environment {
    variables = {
      GITHUB_CREDENTIALS    = var.github_credentials
      dispatch_shared_token = var.dispatch_shared_token
      CORS_ORIGIN           = var.cors_origin
      USER_AGENT            = var.component
      GITHUB_OWNER          = var.github_owner
      GITHUB_REPO           = var.github_repo
    }
  }
}