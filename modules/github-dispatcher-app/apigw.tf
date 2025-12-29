resource "aws_apigatewayv2_api" "api" {
  name          = "${var.component}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [var.cors_origin]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type", "x-audit-key"]
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  count                  = var.deploy_lambda ? 1 : 0
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.dispatcher[0].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "dispatch" {
  count     = var.deploy_lambda ? 1 : 0
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /github/dispatch"
  target    = "integrations/${aws_apigatewayv2_integration.lambda[0].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  count         = var.deploy_lambda ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatcher[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}