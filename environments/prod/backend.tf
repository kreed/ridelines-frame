# Backend configuration for production environment

terraform {
  backend "s3" {
    bucket       = "terraform-284419413007"
    key          = "ridelines-frame/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
