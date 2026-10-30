output "table_name" {
  value = aws_dynamodb_table.customers.name
}

output "lambda_function_arn" {
  value = aws_lambda_function.lookup.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.lookup.function_name
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
