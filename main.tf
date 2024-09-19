# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      hashicorp = "lambda-api-gateway"
    }
  }

}

resource "random_pet" "lambda_bucket_name" {
  prefix = "terraform-functions"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_ownership_controls" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket]

  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

data "archive_file" "lambda_login" {
  type = "zip"

  source_dir  = "${path.module}/login"
  output_path = "${path.module}/login.zip"
}

resource "aws_s3_object" "lambda_login" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "login.zip"
  source = data.archive_file.lambda_login.output_path

  etag = filemd5(data.archive_file.lambda_login.output_path)
}

resource "aws_lambda_function" "login" {
  function_name = "HelloWorld"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_login.key

  runtime = "nodejs20.x"
  handler = "hello.handler"

  source_code_hash = data.archive_file.lambda_login.output_base64sha256

  role = "arn:aws:iam::182028773449:role/LabRole"

  environment {
    variables = {
      COGNITO_USER_POOL_ID = module.aws_cognito_user_pool_complete.user_pool_id
      COGNITO_CLIENT_ID    = module.aws_cognito_user_pool_complete.user_pool_client_id
    }
  }
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "login" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.login.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "login" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.login.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "user_pool_client_pos_tech"
  user_pool_id = module.aws_cognito_user_pool_complete.user_pool_id
}

module "aws_cognito_user_pool_complete" {
  source  = "lgallard/cognito-user-pool/aws"

  user_pool_name           = aws_cognito_user_pool_client.client.id
  alias_attributes         = ["custom:cpf"]  
  auto_verified_attributes = []

  deletion_protection = "ACTIVE"

  password_policy = {
    minimum_length    = 10
    require_lowercase = false
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  schemas = [
    {
      attribute_data_type      = "String"
      developer_only_attribute = false
      mutable                  = true
      name                     = "custom:cpf"  # Adiciona o atributo CPF
      required                 = true

      string_attribute_constraints = {
        min_length = 11
        max_length = 11
      }
    }
  ]

  recovery_mechanisms = []

  tags = {
    hashicorp = "cognito-user-pool"
  }
}