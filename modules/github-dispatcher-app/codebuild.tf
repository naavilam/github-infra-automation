resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "${var.name_prefix}-${var.component}-lambda-artifacts"
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# opcional (mas recomendado): bloquear ACL pública
resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  bucket                  = aws_s3_bucket.lambda_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



resource "aws_codebuild_project" "lambda_builder" {
  name         = "${var.component}-lambda-builder"
  service_role = aws_iam_role.codebuild.arn

  artifacts { type = "NO_ARTIFACTS" }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "NO_SOURCE"
    buildspec = <<YAML
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.11
  build:
    commands:
      - set -euo pipefail
      - echo "SOURCE_ZIP_S3=$SOURCE_ZIP_S3"
      - echo "DEST_BUCKET=$DEST_BUCKET"
      - echo "DEST_KEY=$DEST_KEY"

      - mkdir -p /tmp/src
      - aws s3 cp "$SOURCE_ZIP_S3" /tmp/source.zip
      - unzip -q /tmp/source.zip -d /tmp/src

      # ajuste ESTE caminho para onde o handler está dentro do source.zip
      - test -f /tmp/src/modules/github-dispatcher-app/lambda/lambda_function.py
      - mkdir -p build/pkg
      - python -m pip install --upgrade pip
      - python -m pip install PyJWT -t build/pkg
      - cp -v /tmp/src/modules/github-dispatcher-app/lambda/lambda_function.py build/pkg/lambda_function.py

      - (cd build/pkg && zip -qr ../lambda.zip .)
      - aws s3 cp build/lambda.zip "s3://$DEST_BUCKET/$DEST_KEY"
YAML
  }
}