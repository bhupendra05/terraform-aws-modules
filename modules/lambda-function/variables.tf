variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "description" {
  description = "Lambda function description"
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Lambda runtime (e.g. python3.12, nodejs20.x, go1.x)"
  type        = string
  default     = "python3.12"
}

variable "handler" {
  description = "Lambda handler (filename.function_name)"
  type        = string
  default     = "handler.lambda_handler"
}

variable "filename" {
  description = "Path to local ZIP file (mutually exclusive with s3_bucket/s3_key)"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the Lambda ZIP"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key for the Lambda ZIP"
  type        = string
  default     = null
}

variable "timeout" {
  description = "Lambda timeout in seconds (max 900)"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda memory in MB (128-10240)"
  type        = number
  default     = 128
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "vpc_id" {
  description = "VPC ID if Lambda should run inside a VPC (optional)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Private subnet IDs for VPC Lambda"
  type        = list(string)
  default     = []
}

variable "dlq_arn" {
  description = "Dead letter queue ARN (SQS or SNS)"
  type        = string
  default     = null
}

variable "additional_policy_json" {
  description = "Additional IAM policy JSON to attach to Lambda role"
  type        = string
  default     = null
}

variable "invoke_principal" {
  description = "AWS principal allowed to invoke (e.g. apigateway.amazonaws.com)"
  type        = string
  default     = null
}

variable "invoke_source_arn" {
  description = "Source ARN for invoke permission"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
