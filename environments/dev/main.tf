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

  project_name         = var.project_name
  environment          = local.environment
  domain_name          = var.domain_name
  hosted_zone_id       = module.dns.hosted_zone_id
  price_class          = var.cloudfront_price_class
  enable_logging       = var.enable_cloudfront_logging
  chainring_lambda_url = module.chainring.lambda_function_url
  tags                 = local.common_tags
}

# Chainring API module (new tRPC backend that owns the users table)
module "chainring" {
  source = "../../modules/chainring"

  project_name                = var.project_name
  environment                 = local.environment
  clerk_secret_key            = var.clerk_secret_key
  clerk_publishable_key       = var.clerk_publishable_key
  clerk_jwt_key               = var.clerk_jwt_key
  allowed_origins             = ["https://${var.domain_name}", "http://localhost:5173"]
  cloudfront_distribution_arn = module.website.cloudfront_distribution_arn
  tags                        = local.common_tags
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
  users_table_name            = module.chainring.users_table_name
  users_table_arn             = module.chainring.users_table_arn
  clerk_secret_key            = var.clerk_secret_key
  tags                        = local.common_tags
}

# GitHub Actions IAM module
module "github_actions" {
  source = "../../modules/github-actions-iam"

  project_name      = var.project_name
  environment       = local.environment
  github_repository = var.github_repository
  tags              = local.common_tags
}