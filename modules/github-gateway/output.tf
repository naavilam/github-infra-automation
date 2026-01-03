output "dispatch_urls" {
  value = {
    for k in keys(local.backends) :
    k => "${aws_apigatewayv2_api.api.api_endpoint}/github/dispatch/${k}"
  }
}