


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
  depends_on = [ aws_cognito_user_pool_client.user_pool_client, aws_cognito_user_pool.pool]
  function_name = "Login"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_login.key

  runtime = "nodejs20.x"
  handler = "login.handler"

  source_code_hash = data.archive_file.lambda_login.output_base64sha256

  role = "arn:aws:iam::182028773449:role/LabRole"

  environment {
    variables = {
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.pool.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.user_pool_client.id
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:eu-west-1:111122223333:rule/RunDaily"
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

resource "aws_apigatewayv2_integration" "register" {
  api_id             = aws_apigatewayv2_api.lambda.id
  integration_type   = "AWS_PROXY" 
  integration_uri    = aws_lambda_function.login.invoke_arn
}

resource "aws_apigatewayv2_integration" "login" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.login.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "login" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /auth/login"
  target    = "integrations/${aws_apigatewayv2_integration.login.id}"
}

resource "aws_apigatewayv2_route" "register" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /auth/register"
  target    = "integrations/${aws_apigatewayv2_integration.register.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_cognito_user_pool" "pool" {
  name = "postech_user_pool"
  auto_verified_attributes = []

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  schema {
    name = "cpf"
    attribute_data_type = "String"
    mutable = true
    string_attribute_constraints {
      min_length = 11
      max_length = 11
    }
  }

   schema {
    name = "email"
    attribute_data_type = "String"
    mutable = true
    required = true  
  }

  schema {
    name = "name"
    attribute_data_type = "String"
    mutable = true
    required = true  
  }

  schema {
    name = "phone_number"
    attribute_data_type = "String"
    mutable = true
  }


  tags = {
    postech = "user_pool"
  }
  username_attributes = [ "email"  ]
  
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  depends_on = [ aws_cognito_user_pool.pool ]
  name         = "pos-tech_pool_client"
  user_pool_id = aws_cognito_user_pool.pool.id
  generate_secret = false

  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid"]
  allowed_oauth_flows_user_pool_client = true

  callback_urls = ["https://example.com"]
  logout_urls   = ["http://localhost:3000/logout"]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

}

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "pos-tech-hiago-marques"  
  user_pool_id = aws_cognito_user_pool.pool.id
}
