


resource "aws_codebuild_project" "lambda_builder" {
  name         = "lambda-builder"
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
      - bash -lc 'set -euo pipefail'
      - echo "SOURCE_ZIP_S3=$SOURCE_ZIP_S3"
      - echo "DEST_BUCKET=$DEST_BUCKET"
      - echo "DEST_KEY=$DEST_KEY"

      - mkdir -p /tmp/src
      - aws s3 cp "$SOURCE_ZIP_S3" /tmp/source.zip
      - unzip -q /tmp/source.zip -d /tmp/src

      # ajuste ESTE caminho para onde o handler está dentro do source.zip
      - FOUND="$(find /tmp/src -name lambda_function.py -print -quit)" ; test -n "$FOUND" || (echo "lambda_function.py não encontrado dentro do source.zip" && find /tmp/src -maxdepth 4 -type f | head -200 && exit 1)
      - mkdir -p build/pkg
      - python -m pip install --upgrade pip
      - python -m pip install PyJWT -t build/pkg
      - cp -v "$FOUND" build/pkg/lambda_function.py
      - (cd build/pkg && zip -qr ../lambda.zip .)
      - aws s3 cp build/lambda.zip "s3://$DEST_BUCKET/$DEST_KEY"
YAML
  }
}