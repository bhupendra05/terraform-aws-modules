terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name    = "${var.project_name}-${var.environment}"
  cidr    = "10.0.0.0/16"
  azs     = ["${var.aws_region}a", "${var.aws_region}b"]

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_nat_gateway = var.environment == "production"

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Lambda (API backend)
# ---------------------------------------------------------------------------

module "api_lambda" {
  source = "../../modules/lambda-function"

  function_name = "${var.project_name}-${var.environment}-api"
  description   = "API handler for ${var.project_name}"
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  filename      = "${path.module}/lambda.zip"
  timeout       = 30
  memory_size   = 256

  environment_variables = {
    ENVIRONMENT = var.environment
    LOG_LEVEL   = var.environment == "production" ? "WARNING" : "DEBUG"
  }

  # Run Lambda inside VPC to access private resources (RDS, ElastiCache)
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # Allow API Gateway to invoke
  invoke_principal = "apigateway.amazonaws.com"

  log_retention_days = var.environment == "production" ? 30 : 7

  tags = local.tags
}

# ---------------------------------------------------------------------------
# S3 + CloudFront (Frontend)
# ---------------------------------------------------------------------------

module "frontend" {
  source = "../../modules/s3-static-site"

  bucket_name         = "${var.project_name}-${var.environment}-frontend-${var.aws_region}"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  # Uncomment and set when you have a custom domain + ACM cert
  # domain_names        = ["app.example.com"]
  # acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "api_lambda_arn" {
  value = module.api_lambda.function_arn
}

output "api_lambda_name" {
  value = module.api_lambda.function_name
}

output "frontend_url" {
  value = module.frontend.cloudfront_url
}

output "frontend_bucket" {
  value = module.frontend.bucket_id
}

output "cloudfront_distribution_id" {
  value = module.frontend.cloudfront_distribution_id
}
