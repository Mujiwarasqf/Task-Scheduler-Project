terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws     = { source = "hashicorp/aws",     version = ">= 5.0" }
    archive = { source = "hashicorp/archive", version = ">= 2.4" }
    random  = { source = "hashicorp/random",  version = ">= 3.6" }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  table_name = "${var.project}-tasks"
  topic_name = "${var.project}-notifications"
}

# ---------------- DynamoDB ----------------
resource "aws_dynamodb_table" "tasks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "due_date"
    type = "S"
  }

  global_secondary_index {
    name            = "gsi_due_date"
    hash_key        = "due_date"
    projection_type = "ALL"
  }
}

# ---------------- SNS ----------------
resource "aws_sns_topic" "due" {
  name = local.topic_name
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.due.arn
  protocol  = "email"
  endpoint  = var.email
}

# ---------------- IAM (Lambda) ----------------
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "aws_iam_policy_document" "lambda_basic" {
  statement {
    actions   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_basic" {
  name   = "${var.project}-lambda-basic"
  policy = data.aws_iam_policy_document.lambda_basic.json
}

data "aws_iam_policy_document" "lambda_ddb_sns" {
  statement {
    actions = ["dynamodb:PutItem","dynamodb:Query","dynamodb:UpdateItem","dynamodb:GetItem","dynamodb:Scan"]
    resources = [
      aws_dynamodb_table.tasks.arn,
      "${aws_dynamodb_table.tasks.arn}/index/*"
    ]
  }
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.due.arn]
  }
}

resource "aws_iam_policy" "lambda_ddb_sns" {
  name   = "${var.project}-lambda-ddb-sns"
  policy = data.aws_iam_policy_document.lambda_ddb_sns.json
}

resource "aws_iam_role_policy_attachment" "attach_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_basic.arn
}

resource "aws_iam_role_policy_attachment" "attach_ddb_sns" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_ddb_sns.arn
}

# ---------------- Lambda packages ----------------
data "archive_file" "create_task_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/create_task.py"
  output_path = "${path.module}/lambdas/create_task.zip"
}

data "archive_file" "list_tasks_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/list_tasks.py"
  output_path = "${path.module}/lambdas/list_tasks.zip"
}

data "archive_file" "complete_task_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/complete_task.py"
  output_path = "${path.module}/lambdas/complete_task.zip"
}

data "archive_file" "notify_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/notify_due_today.py"
  output_path = "${path.module}/lambdas/notify_due_today.zip"
}

resource "aws_lambda_function" "create_task" {
  function_name = "${var.project}-create-task"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.12"
  handler       = "create_task.handler"
  filename      = data.archive_file.create_task_zip.output_path
  source_code_hash = data.archive_file.create_task_zip.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.tasks.name } }
}

resource "aws_lambda_function" "list_tasks" {
  function_name = "${var.project}-list-tasks"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.12"
  handler       = "list_tasks.handler"
  filename      = data.archive_file.list_tasks_zip.output_path
  source_code_hash = data.archive_file.list_tasks_zip.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.tasks.name } }
}

resource "aws_lambda_function" "complete_task" {
  function_name = "${var.project}-complete-task"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.12"
  handler       = "complete_task.handler"
  filename      = data.archive_file.complete_task_zip.output_path
  source_code_hash = data.archive_file.complete_task_zip.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.tasks.name } }
}

resource "aws_lambda_function" "notify" {
  function_name = "${var.project}-notify-due-today"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.12"
  handler       = "notify_due_today.handler"
  filename      = data.archive_file.notify_zip.output_path
  source_code_hash = data.archive_file.notify_zip.output_base64sha256
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.tasks.name
      TOPIC_ARN  = aws_sns_topic.due.arn
      TZ         = "Europe/London"
    }
  }
}

# ---------------- API Gateway (HTTP API) with CORS ----------------
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["content-type"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = ["*"]
  }
}

resource "aws_apigatewayv2_integration" "create" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_task.invoke_arn
  payload_format_version = "2.0"
}
resource "aws_apigatewayv2_route" "create" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /tasks"
  target    = "integrations/${aws_apigatewayv2_integration.create.id}"
}

resource "aws_apigatewayv2_integration" "list" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.list_tasks.invoke_arn
  payload_format_version = "2.0"
}
resource "aws_apigatewayv2_route" "list" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /tasks"
  target    = "integrations/${aws_apigatewayv2_integration.list.id}"
}

resource "aws_apigatewayv2_integration" "complete" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.complete_task.invoke_arn
  payload_format_version = "2.0"
}
resource "aws_apigatewayv2_route" "complete" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /tasks/{task_id}/complete"
  target    = "integrations/${aws_apigatewayv2_integration.complete.id}"
}

resource "aws_lambda_permission" "api_create" {
  statement_id  = "AllowAPIGatewayInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
resource "aws_lambda_permission" "api_list" {
  statement_id  = "AllowAPIGatewayInvokeList"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_tasks.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
resource "aws_lambda_permission" "api_complete" {
  statement_id  = "AllowAPIGatewayInvokeComplete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.complete_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# ---------------- EventBridge Scheduler (08:00 Europe/London) ----------------
data "aws_iam_policy_document" "assume_scheduler" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "scheduler_invoke" {
  name               = "${var.project}-scheduler-invoke"
  assume_role_policy = data.aws_iam_policy_document.assume_scheduler.json
}
data "aws_iam_policy_document" "scheduler_policy" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.notify.arn]
  }
}
resource "aws_iam_policy" "scheduler_policy" {
  name   = "${var.project}-scheduler-policy"
  policy = data.aws_iam_policy_document.scheduler_policy.json
}
resource "aws_iam_role_policy_attachment" "attach_scheduler" {
  role       = aws_iam_role.scheduler_invoke.name
  policy_arn = aws_iam_policy.scheduler_policy.arn
}
resource "aws_scheduler_schedule" "daily_8am_uk" {
  name                         = "${var.project}-daily-8am-uk"
  schedule_expression          = "cron(0 8 * * ? *)"
  schedule_expression_timezone = "Europe/London"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_lambda_function.notify.arn
    role_arn = aws_iam_role.scheduler_invoke.arn
  }
}

# ---------------- Static UI: S3 + CloudFront (no Route 53) ----------------
resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "ui" {
  bucket        = "${var.project}-ui-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "ui" {
  bucket = aws_s3_bucket.ui.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_versioning" "ui" {
  bucket = aws_s3_bucket.ui.id
  versioning_configuration { status = "Enabled" }
}

# Origin Access Control (modern, replaces OAI)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project}-oac"
  description                       = "OAC for S3 UI origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name = aws_s3_bucket.ui.bucket_regional_domain_name
    origin_id   = "s3-ui-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-ui-origin"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_caller_identity" "current" {}

# S3 bucket policy to allow CloudFront OAC
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalReadOnly"
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.ui.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "ui" {
  bucket = aws_s3_bucket.ui.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# -------- Upload UI files to S3 (index.html, app.js, config.json) --------
# config.json contains the deployed API base URL for the frontend to call.
resource "aws_s3_object" "config" {
  bucket        = aws_s3_bucket.ui.id
  key           = "config.json"
  content_type  = "application/json"
  cache_control = "no-cache, no-store, must-revalidate"
  content       = jsonencode({ apiBaseUrl = aws_apigatewayv2_api.api.api_endpoint })
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.ui.id
  key          = "index.html"
  content_type = "text/html"
  content      = file("${path.module}/ui/index.html")
}

resource "aws_s3_object" "app" {
  bucket       = aws_s3_bucket.ui.id
  key          = "app.js"
  content_type = "application/javascript"
  content      = file("${path.module}/ui/app.js")
}