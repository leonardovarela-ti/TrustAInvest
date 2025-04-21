# This file modifies the storage module configuration to fix issues with S3 bucket ACLs for CloudFront and ALB logs

# CloudFront and ALB require ACLs to be enabled on the S3 bucket to write logs
# We need to add ownership controls and enable ACLs for the logs bucket

# Create a new S3 bucket ownership controls resource for the logs bucket
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = module.storage.logs_bucket_name

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Create a new S3 bucket ACL resource for the logs bucket
resource "aws_s3_bucket_acl" "logs" {
  bucket = module.storage.logs_bucket_name
  acl    = "log-delivery-write"

  # The ACL can only be set after the ownership controls
  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

# Update the existing S3 bucket policy to allow ALB and CloudFront to write logs
resource "aws_s3_bucket_policy" "logs_updated" {
  bucket = module.storage.logs_bucket_name

  # The policy can only be set after the ACL
  depends_on = [aws_s3_bucket_acl.logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root" # AWS ELB service account for us-east-1
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}/alb-logs/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}/alb-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}/cloudfront-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}/alb-logs/*"
      }
    ]
  })
}

# The resources above will enable CloudFront and ALB logs to write to the S3 bucket
