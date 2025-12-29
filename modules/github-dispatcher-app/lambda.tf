locals {
  build_dir  = "${path.module}/.build"
  lambda_src = "${path.module}/lambda/lambda_function.py"
  lambda_s3_key = "${var.component}/lambda.zip"
}

resource "null_resource" "build_lambda" {
  triggers = {
    src_hash = filesha256(local.lambda_src)
  }

provisioner "local-exec" {
    command = <<EOT
set -e
rm -rf ${local.build_dir}
mkdir -p ${local.build_dir}/pkg

python3 -m pip install --upgrade pip >/dev/null
python3 -m pip install PyJWT -t ${local.build_dir}/pkg >/dev/null

cp ${local.lambda_src} ${local.build_dir}/pkg/lambda_function.py

cd ${local.build_dir}/pkg
zip -qr ../lambda.zip .
EOT
  }
}

# Gera o ZIP durante o PLAN/APPLY (sem depender de local-exec)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local.lambda_src
  output_path = "${path.module}/lambda.zip"
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

  s3_bucket         = aws_s3_bucket.lambda_artifacts.bucket
  s3_key            = local.lambda_s3_key
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
