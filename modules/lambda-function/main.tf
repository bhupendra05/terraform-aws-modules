# IAM role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

# Basic execution policy (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC execution policy (if VPC-attached)
resource "aws_iam_role_policy_attachment" "vpc" {
  count      = var.vpc_id != null ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Additional inline policies
resource "aws_iam_role_policy" "additional" {
  count  = var.additional_policy_json != null ? 1 : 0
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = var.additional_policy_json
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Security group for VPC Lambda
resource "aws_security_group" "lambda" {
  count       = var.vpc_id != null ? 1 : 0
  name        = "${var.function_name}-sg"
  description = "Security group for Lambda ${var.function_name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.function_name}-sg" })
}

# Lambda function
resource "aws_lambda_function" "main" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.lambda.arn

  # Package
  filename         = var.filename
  source_code_hash = var.filename != null ? filebase64sha256(var.filename) : null
  s3_bucket        = var.s3_bucket
  s3_key           = var.s3_key

  runtime     = var.runtime
  handler     = var.handler
  timeout     = var.timeout
  memory_size = var.memory_size

  environment {
    variables = var.environment_variables
  }

  dynamic "vpc_config" {
    for_each = var.vpc_id != null ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dlq_arn != null ? [1] : []
    content {
      target_arn = var.dlq_arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.basic,
  ]

  tags = var.tags
}

# Optional: allow invocation from another AWS service (e.g. API Gateway)
resource "aws_lambda_permission" "invoke" {
  count         = var.invoke_principal != null ? 1 : 0
  statement_id  = "AllowExternalInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = var.invoke_principal
  source_arn    = var.invoke_source_arn
}
