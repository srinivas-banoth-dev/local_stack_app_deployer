
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
#   allowed_account_ids = ["000000000000"]
#   s3_force_path_style         = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    s3     = "http://localhost:4566"
    lambda = "http://localhost:4566"
    iam    = "http://localhost:4566"
    apigateway = "http://localhost:4566"
    elb = "http://localhost:4566"
    # lb   = "http://localhost:4566"
    elbv2 = "http://localhost:4566"
    ec2   = "http://localhost:4566"
  }
}
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "my-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_instance" "myec2" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  key_name      = "my-key"

  tags = {
    Name = "MyEC2Instance"
  }
}
# resource "aws_lb" "myalb" {
#   name               = "my-alb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = ["sg-12345678"]
#   subnets            = ["subnet-12345678", "subnet-87654321"]

#   enable_deletion_protection = false
# }

resource "aws_lb_target_group" "mytargetgroup" {
  name     = "my-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-12345678"
}

resource "aws_lb_listener" "mylistener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mytargetgroup.arn
  }
}


# module "eks" {
#    source  = "terraform-aws-modules/eks/aws"
#   version = "20.15.0"
#   cluster_name    = "my-cluster"
#   cluster_version = "1.21"
#   subnets         = ["subnet-12345678", "subnet-87654321"]
#   vpc_id          = "vpc-12345678"

#   node_groups = {
#     eks_nodes = {
#       desired_capacity = 2
#       max_capacity     = 3
#       min_capacity     = 1

#       instance_type = "t3.medium"
#     }
#   }
# }
data "archive_file" "lambda_hello_world" {
  type = "zip"
  source_dir  = "${path.module}/hello-world"
  output_path = "${path.module}/hello-world.zip"
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
resource "aws_api_gateway_rest_api" "myapi" {
  name        = "my_api"
  description = "API Gateway for my CRUD application"
}
resource "aws_api_gateway_resource" "myresource" {
  rest_api_id = aws_api_gateway_rest_api.myapi.id
  parent_id   = aws_api_gateway_rest_api.myapi.root_resource_id
  path_part   = "myresource"
}

resource "aws_api_gateway_method" "mymethod" {
  rest_api_id   = aws_api_gateway_rest_api.myapi.id
  resource_id   = aws_api_gateway_resource.myresource.id
  http_method   = "GET"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "myintegration" {
  rest_api_id = aws_api_gateway_rest_api.myapi.id
  resource_id = aws_api_gateway_resource.myresource.id
  http_method = aws_api_gateway_method.mymethod.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.hello-word.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello-word.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.myapi.execution_arn}/*/*"
}
resource "aws_lambda_function" "hello-word" {
    function_name = "HelloWorld"
    filename = "hello-world.zip"
    runtime = "nodejs18.x"
    handler = "index.handler"
    source_code_hash = data.archive_file.lambda_hello_world.output_base64sha256
    role = aws_iam_role.lambda_exec.arn
    
}