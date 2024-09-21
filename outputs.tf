# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Output value definitions

output "lambda_bucket_name" {
  description = "Nome do arquivo s3 usado para armazenar o código do Lambda."

  value = aws_s3_bucket.lambda_bucket.id
}

output "function_name" {
  description = "Nome da função Lambda."

  value = aws_lambda_function.login.function_name
}

output "base_url" {
  description = "URL base da API Gateway."

  value = aws_apigatewayv2_stage.lambda.invoke_url
}

output "aws_cognito_user_pool_pool_id" {
  description = "O ID do pool de usuários Cognito"
  value       = aws_cognito_user_pool.pool.id
}

output "aws_cognito_user_pool_client_user_pool_client_id" {
  description = "O Client ID do pool de usuários Cognito"
  value       = aws_cognito_user_pool_client.user_pool_client.id
}