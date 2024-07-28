
provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"
  #   allowed_account_ids = ["000000000000"]
  # allowed_account_ids = [000000000000]
  #   s3_force_path_style         = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    s3         = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    iam        = "http://localhost:4566"
    apigateway = "http://localhost:4566"
    elb        = "http://localhost:4566"
    # lb   = "http://localhost:4566"
    elbv2 = "http://localhost:4566"
    ec2   = "http://localhost:4566"
    eks   = "http://localhost:4566"
    logs           = "http://localhost:4566"
  }
}
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}
data "archive_file" "lambda_hello_world" {
  type        = "zip"
  source_dir  = "../api/hello-world"
  output_path = "${path.module}/hello-world.zip"
}
resource "aws_lambda_function" "hello_world" {
  function_name = "hello-world"
  role          = aws_iam_role.lambda_exec.arn
  runtime          = "nodejs18.x"
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_hello_world.output_base64sha256
  filename = "hello-world.zip"
}
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/hello-world"
  retention_in_days = 7
}
resource "aws_api_gateway_rest_api" "hello_world_api" {
  name        = "HelloWorldAPI"
  description = "API to return Hello World"
}

resource "aws_api_gateway_resource" "hello_world_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  parent_id   = aws_api_gateway_rest_api.hello_world_api.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello_world_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_world_api.id
  resource_id   = aws_api_gateway_resource.hello_world_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "hello_world_integration" {
  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  resource_id = aws_api_gateway_resource.hello_world_resource.id
  http_method = aws_api_gateway_method.hello_world_method.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.hello_world.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.hello_world_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "hello_world_deployment" {
  depends_on = [
    aws_api_gateway_integration.hello_world_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  stage_name  = "dev"
}

output "api_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.hello_world_api.id}/dev/_user_request_/hello"
}