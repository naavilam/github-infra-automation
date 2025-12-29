output "dispatch_url" {
  value = "${aws_apigatewayv2_api.api.api_endpoint}/github/dispatch"
}

output "secret_arn" {
  value = aws_secretsmanager_secret.credentials.arn
}