locals {
  repo_root   = abspath("${path.root}/../..")
  lambda_src  = "${local.repo_root}/lambda/lambda_function.py"
  build_dir   = "${path.module}/.build"
}

resource "null_resource" "build_lambda" {
  triggers = {
    src_hash = filesha256(local.lambda_src)
  }

  provisioner "local-exec" {
    command = <<EOT
set -e
rm -rf ${local.build_dir} && mkdir -p ${local.build_dir}/pkg
python3 -m pip install --upgrade pip >/dev/null
python3 -m pip install PyJWT -t ${local.build_dir}/pkg >/dev/null
cp ${local.lambda_src} ${local.build_dir}/pkg/lambda_function.py
cd ${local.build_dir}/pkg
zip -qr ${local.build_dir}/lambda.zip .
EOT
  }
}

resource "aws_lambda_function" "dispatcher" {
  function_name = "${var.component}-dispatcher"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.11"
  timeout       = 30

  filename         = "${local.build_dir}/lambda.zip"
  source_code_hash = filebase64sha256("${local.build_dir}/lambda.zip")

  environment {
    variables = {
      GITHUB_SECRET_ARN      = aws_secretsmanager_secret.credentials.arn
      DISPATCH_SHARED_SECRET = var.dispatch_shared_secret
      CORS_ORIGIN            = var.cors_origin
      USER_AGENT             = var.component
    }
  }

  depends_on = [
    null_resource.build_lambda,
    aws_secretsmanager_secret_version.credentials
  ]
}