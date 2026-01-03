output "dispatcher_invoke_arn" {
  value = aws_lambda_function.dispatcher.invoke_arn
}

output "dispatcher_function_name" {
  value = aws_lambda_function.dispatcher.function_name
}