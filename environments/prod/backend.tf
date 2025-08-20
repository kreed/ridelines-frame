# Backend configuration for production environment

terraform {
  backend "s3" {
    bucket = "ridelines-terraform-state"
    key    = "ridelines-frame/prod/terraform.tfstate"
    region = "us-west-2"
    
    # DynamoDB table for state locking
    dynamodb_table = "ridelines-terraform-locks"
    encrypt        = true
  }
}