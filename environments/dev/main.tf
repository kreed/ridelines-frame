# Development environment configuration for Ridelines Frame

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.9"
    }
  }
  
  backend "s3" {
    # Backend configuration will be provided via backend.tf
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

# AWS provider for us-east-1 (required for CloudFront certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

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
  
  # Read package versions from versions.yml
  hub_version    = var.hub_version
  lambda_version = var.lambda_version
  layer_version  = var.layer_version
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
  
  project_name    = var.project_name
  environment     = local.environment
  domain_name     = var.domain_name
  hosted_zone_id  = module.dns.hosted_zone_id
  price_class     = var.cloudfront_price_class
  enable_logging  = var.enable_cloudfront_logging
  tags            = local.common_tags

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

# Athlete state module (GeoJSON S3 bucket)
module "athlete_state" {
  source = "../../modules/athlete-state"
  
  project_name = var.project_name
  environment  = local.environment
  tags         = local.common_tags
}

# Drivetrain Lambda module
module "drivetrain_lambda" {
  source = "../../modules/drivetrain-lambda"
  
  project_name               = var.project_name
  environment                = local.environment
  lambda_package_path        = var.lambda_package_path
  tippecanoe_layer_arn       = var.tippecanoe_layer_arn
  athlete_state_bucket_name  = module.athlete_state.bucket_name
  athlete_state_bucket_arn   = module.athlete_state.bucket_arn
  activities_bucket_name     = module.website.activities_bucket_name
  activities_bucket_arn      = "arn:aws:s3:::${module.website.activities_bucket_name}"
  cloudfront_distribution_id = module.website.cloudfront_distribution_id
  cloudfront_distribution_arn = module.website.cloudfront_distribution_arn
  enable_function_url        = var.enable_lambda_function_url
  tags                       = local.common_tags
}