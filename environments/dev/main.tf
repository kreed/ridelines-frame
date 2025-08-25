# Development environment configuration for Ridelines Frame

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.9"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# Local values for development environment
locals {
  environment = "dev"

  common_tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
  }

}

# DNS module
module "dns" {
  source = "../../modules/dns"

  domain_name = var.domain_name
  tags        = local.common_tags
}

# Website module (CloudFront + S3 buckets + ACM certificate)
module "website" {
  source = "../../modules/website"

  project_name   = var.project_name
  environment    = local.environment
  domain_name    = var.domain_name
  hosted_zone_id = module.dns.hosted_zone_id
  price_class    = var.cloudfront_price_class
  enable_logging = var.enable_cloudfront_logging
  tags           = local.common_tags
}

# Users module (DynamoDB table for user profiles and sync status)
module "drivetrain_users" {
  source = "../../modules/drivetrain-users"

  project_name = var.project_name
  environment  = local.environment
  tags         = local.common_tags
}

# Auth module (OAuth infrastructure)
module "drivetrain_auth" {
  source = "../../modules/drivetrain-auth"

  project_name     = var.project_name
  environment      = local.environment
  users_table_name = module.drivetrain_users.users_table_name
  users_table_arn  = module.drivetrain_users.users_table_arn
  tags             = local.common_tags
}

# Sync module (existing activity sync functionality)
module "drivetrain_sync" {
  source = "../../modules/drivetrain-sync"

  project_name                = var.project_name
  environment                 = local.environment
  activities_bucket_name      = module.website.activities_bucket_name
  activities_bucket_arn       = "arn:aws:s3:::${module.website.activities_bucket_name}"
  cloudfront_distribution_id  = module.website.cloudfront_distribution_id
  cloudfront_distribution_arn = module.website.cloudfront_distribution_arn
  users_table_name            = module.drivetrain_users.users_table_name
  users_table_arn             = module.drivetrain_users.users_table_arn
  tags                        = local.common_tags
}

# API Gateway module
module "api_gateway" {
  source = "../../modules/api-gateway"

  environment               = local.environment
  domain_name               = "dev.api.${var.domain_name}"
  route53_zone_id           = module.dns.hosted_zone_id
  auth_lambda_arn           = module.drivetrain_auth.lambda_function_arn
  auth_lambda_function_name = module.drivetrain_auth.lambda_function_name
  user_lambda_arn           = module.drivetrain_users.lambda_function_arn
  user_lambda_function_name = module.drivetrain_users.lambda_function_name
  jwt_kms_key_arn           = module.drivetrain_auth.jwt_signing_key_arn
  frontend_origin           = "https://dev.${var.domain_name}"
  openapi_spec_path         = "artifacts/drivetrain/ridelines-api.yaml"
}

# GitHub Actions IAM module
module "github_actions" {
  source = "../../modules/github-actions-iam"

  project_name      = var.project_name
  environment       = local.environment
  github_repository = var.github_repository
  tags              = local.common_tags
}