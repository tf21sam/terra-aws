terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

#configure the aws provider
provider "aws" {
    region = "ap-south-1"
}

# Create S3 bucket to hold the website
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name
}

# index.html uplode karnge s3 main
resource "aws_s3_bucket_object" "index_html" {
  bucket = aws_s3_bucket.website_bucket.id
  key    = "index.html"
  source = "website/index.html" # Path to the local index.html file
  etag   = filemd5("website/index.html")
  content_type = "text/html"  # Setting the MIME type
}

# error.html uploade karnge s3 main 
resource "aws_s3_bucket_object" "error_html" {
  bucket = aws_s3_bucket.website_bucket.id
  key    = "error.html"
  source = "website/error.html" # Path to the local error.html file
  etag   = filemd5("website/error.html")
  content_type = "text/html"  # Setting the MIME type
}

# CloudFront Origin Access Identity create karnge  ### Acts as a bridge between CloudFront and S3
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Origin Access Identity for static website"
}

# CloudFront Distribution create karnge 
resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = var.bucket_name


    ### Connects CloudFront to S3 bucket OAI ke help se 
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.website_index_document

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.bucket_name

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "CloudFront Distribution"
    Environment = "Production"
  }
}

# S3 Bucket Policy to allow CloudFront Origin Access Identity to read objects
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"
        Principal = {
          CanonicalUser = aws_cloudfront_origin_access_identity.origin_access_identity.s3_canonical_user_id
        }
      }
    ]
  })
}
