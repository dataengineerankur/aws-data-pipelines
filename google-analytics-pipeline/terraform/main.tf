provider "aws" {
  region = "us-east-1"
}

# S3 Bucket for analytics data
resource "aws_s3_bucket" "analytics_data" {
  bucket = "my-ga-analytics-data-${random_string.bucket_suffix.result}"
  force_destroy = true
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "analytics_data" {
  bucket = aws_s3_bucket.analytics_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Glue Catalog Databases
resource "aws_glue_catalog_database" "landing" {
  name = "analytics_landing"
}

resource "aws_glue_catalog_database" "raw" {
  name = "analytics_raw"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "ga-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "ga-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_s3_bucket.analytics_data.arn}/*",
          "arn:aws:logs:*:*:*"
        ]
      }
    ]
  })
}

# IAM Role for Glue
resource "aws_iam_role" "glue_role" {
  name = "ga-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Glue
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  role       = aws_iam_role.glue_role.name
}

resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "ga-glue-s3-policy"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.analytics_data.arn}/*"
      }
    ]
  })
}

# Glue Crawlers
resource "aws_glue_crawler" "landing_crawler" {
  name         = "ga_events_landing_crawler"
  database_name = aws_glue_catalog_database.landing.name
  role         = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.analytics_data.id}/landing/ga_events/"
  }

  schedule = "cron(0 */6 * * ? *)"  # Every 6 hours
}

resource "aws_glue_crawler" "raw_crawler" {
  name         = "ga_events_raw_crawler"
  database_name = aws_glue_catalog_database.raw.name
  role         = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.analytics_data.id}/raw/ga_events/"
  }

  schedule = "cron(0 */6 * * ? *)"  # Every 6 hours
}

# Outputs
output "s3_bucket_name" {
  value = aws_s3_bucket.analytics_data.id
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "glue_role_arn" {
  value = aws_iam_role.glue_role.arn
} 