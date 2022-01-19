terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.48.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

# LAMBDA

module "python_lambda_archive" {
  source = "rojopolis/lambda-python-archive/aws"

  src_dir     = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "get_copy" {
  function_name = "GetCopy"

  runtime = "python3.8"
  handler = "copy_lambda.get_handler"

  role = aws_iam_role.lambda_exec.arn

  filename         = module.python_lambda_archive.archive_path
  source_code_hash = module.python_lambda_archive.source_code_hash
}

resource "aws_lambda_function" "save_copy" {
  function_name = "SaveCopy"

  runtime = "python3.8"
  handler = "copy_lambda.save_handler"

  role = aws_iam_role.lambda_exec.arn

  filename         = module.python_lambda_archive.archive_path
  source_code_hash = module.python_lambda_archive.source_code_hash
}

resource "aws_iam_role" "lambda_exec" {
  name = "copy_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_exec.name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource" : "arn:aws:dynamodb:eu-west-2:140551133576:table/copy"
      }
    ]
  })
}

# DYNAMODB

resource "aws_dynamodb_table" "copy" {
  name         = "copy"
  hash_key     = "id"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "id"
    type = "S"
  }
}

# API GATEWAY

resource "aws_apigatewayv2_api" "lambda" {
  name          = "copy_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "prod"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "get_copy" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get_copy.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "save_copy" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.save_copy.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_copy" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /copy"
  target    = "integrations/${aws_apigatewayv2_integration.get_copy.id}"
}

resource "aws_apigatewayv2_route" "save_copy" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /copy"
  target    = "integrations/${aws_apigatewayv2_integration.save_copy.id}"
}

resource "aws_lambda_permission" "get_copy_api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_copy.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "save_copy_api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.save_copy.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}