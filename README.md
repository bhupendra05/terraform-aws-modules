# Terraform AWS Modules

Production-ready, reusable Terraform modules for AWS — VPC, Lambda, and S3/CloudFront static sites. Each module is self-contained with variables, outputs, and sensible defaults.

## Modules

| Module | What it creates |
|--------|----------------|
| `modules/vpc` | VPC + public/private subnets + IGW + NAT gateway + route tables |
| `modules/lambda-function` | Lambda + IAM role + CloudWatch logs + optional VPC + DLQ |
| `modules/s3-static-site` | S3 + CloudFront (OAC) + cache policies + SPA support |

## Quick Start

```bash
cd examples/full-stack-app
terraform init
terraform plan -var="project_name=myapp" -var="environment=development"
terraform apply
```

## Module Reference

---

### `modules/vpc`

Creates a VPC with public and private subnets across multiple AZs, an internet gateway, optional NAT gateway, and route tables.

```hcl
module "vpc" {
  source = "./modules/vpc"

  name            = "myapp-prod"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  enable_nat_gateway = true

  tags = { Environment = "production" }
}
```

**Inputs:**

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | string | — | Name prefix for all resources |
| `cidr` | string | `10.0.0.0/16` | VPC CIDR block |
| `azs` | list(string) | `["us-east-1a", "us-east-1b"]` | Availability zones |
| `public_subnets` | list(string) | `["10.0.1.0/24", "10.0.2.0/24"]` | Public subnet CIDRs |
| `private_subnets` | list(string) | `["10.0.10.0/24", "10.0.11.0/24"]` | Private subnet CIDRs |
| `enable_nat_gateway` | bool | `true` | Create NAT gateway (adds ~$32/month) |
| `tags` | map(string) | `{}` | Tags for all resources |

**Outputs:** `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_id`, `internet_gateway_id`

---

### `modules/lambda-function`

Creates a Lambda function with its IAM role, CloudWatch log group, and optionally VPC attachment and DLQ.

```hcl
module "api" {
  source = "./modules/lambda-function"

  function_name = "my-api-handler"
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  filename      = "./lambda.zip"
  timeout       = 30
  memory_size   = 256

  environment_variables = {
    DATABASE_URL = "postgresql://..."
  }

  # VPC attachment
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # Dead letter queue
  dlq_arn = aws_sqs_queue.dlq.arn

  tags = { Environment = "production" }
}
```

**Inputs:**

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `function_name` | string | — | Lambda function name |
| `runtime` | string | `python3.12` | Runtime identifier |
| `handler` | string | `handler.lambda_handler` | Handler path |
| `filename` | string | `null` | Local ZIP path |
| `s3_bucket` / `s3_key` | string | `null` | S3-hosted ZIP (alternative to filename) |
| `timeout` | number | `30` | Timeout in seconds |
| `memory_size` | number | `128` | Memory in MB |
| `log_retention_days` | number | `14` | CloudWatch retention |
| `vpc_id` | string | `null` | VPC for Lambda (optional) |
| `dlq_arn` | string | `null` | Dead letter queue ARN |

**Outputs:** `function_arn`, `function_name`, `invoke_arn`, `role_arn`, `log_group_name`

---

### `modules/s3-static-site`

Creates an S3 bucket with CloudFront distribution using Origin Access Control (OAC). Supports custom domains, HTTPS, and SPA routing (404 → index.html).

```hcl
module "frontend" {
  source = "./modules/s3-static-site"

  bucket_name         = "myapp-frontend-us-east-1"
  default_root_object = "index.html"

  # Custom domain (optional)
  domain_names        = ["app.example.com"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789:certificate/..."

  tags = { Environment = "production" }
}
```

Deploy files after `terraform apply`:
```bash
aws s3 sync ./dist s3://$(terraform output -raw frontend_bucket) --delete
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

**Inputs:**

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `bucket_name` | string | — | Globally unique S3 bucket name |
| `domain_names` | list(string) | `[]` | Custom domains (requires ACM cert) |
| `acm_certificate_arn` | string | `null` | ACM cert ARN (must be us-east-1) |
| `default_root_object` | string | `index.html` | CloudFront default document |
| `price_class` | string | `PriceClass_100` | `PriceClass_100`=US/EU, `PriceClass_All`=global |

**Outputs:** `bucket_id`, `cloudfront_distribution_id`, `cloudfront_domain_name`, `cloudfront_url`

---

## Full-Stack Example

`examples/full-stack-app/` combines all three modules:
- VPC with public + private subnets
- Lambda in private subnet (can access RDS/ElastiCache)
- CloudFront + S3 for React/Next.js frontend

```bash
cd examples/full-stack-app
terraform init
terraform apply -var="project_name=myapp" -var="environment=production"
```

## Cost Estimates (us-east-1)

| Module | Monthly cost |
|--------|-------------|
| VPC (no NAT) | Free |
| VPC + NAT Gateway | ~$32 (+ data transfer) |
| Lambda (1M req, 256MB, 200ms) | ~$0.50 |
| S3 + CloudFront (10GB transfer) | ~$1.50 |
