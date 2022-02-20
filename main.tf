provider "aws" {
}

terraform {
  required_providers {
    auth0 = {
      source  = "alexkappa/auth0"
      version = "0.17.1"
    }
  }
}

variable "auth0_domain" {}
variable "auth0_client_id" {}
variable "auth0_client_secret" {}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
}

data "aws_region" "current" {
}

resource "random_id" "id" {
  byte_length = 8
}

# auth0

resource "auth0_client" "appsync" {
  name            = "Appsync-test-${random_id.id.hex}"
  app_type        = "spa"
  callbacks       = ["https://${aws_cloudfront_distribution.distribution.domain_name}"]
  oidc_conformant = true
	token_endpoint_auth_method = "none"

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_user" "user1" {
  connection_name = "Username-Password-Authentication"
  email = "user1@example.com"
  email_verified = true
  password = "Password.1"
}

resource "auth0_user" "user2" {
  connection_name = "Username-Password-Authentication"
  email = "user2@example.com"
  email_verified = true
  password = "Password.1"
}

# frontend

resource "aws_s3_bucket" "bucket" {
  force_destroy = "true"
}

locals {
  # Maps file extensions to mime types
  # Need to add more if needed
  mime_type_mappings = {
    html = "text/html",
    js   = "text/javascript",
    mjs  = "text/javascript",
    css  = "text/css"
  }
}

resource "aws_s3_object" "frontend_object" {
  for_each = fileset("${path.module}/frontend", "*")
  key      = each.value
  source   = "${path.module}/frontend/${each.value}"
  bucket   = aws_s3_bucket.bucket.bucket

  etag          = filemd5("${path.module}/frontend/${each.value}")
  content_type  = local.mime_type_mappings[concat(regexall("\\.([^\\.]*)$", each.value), [[""]])[0][0]]
  cache_control = "no-store, max-age=0"
}

resource "aws_s3_object" "frontend_config" {
  key     = "config.js"
  content = <<EOF
export const domain = "${var.auth0_domain}";
export const clientId = "${auth0_client.appsync.client_id}";
export const apiURL = "${aws_appsync_graphql_api.appsync.uris["GRAPHQL"]}"
EOF
  bucket  = aws_s3_bucket.bucket.bucket

  content_type  = "text/javascript"
  cache_control = "no-store, max-age=0"
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "s3"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.OAI.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "OAI_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.OAI.iam_arn]
    }
  }
}

resource "aws_cloudfront_origin_access_identity" "OAI" {
}

output "domain" {
  value = aws_cloudfront_distribution.distribution.domain_name
}

