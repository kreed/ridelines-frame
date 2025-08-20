# Backend configuration for development environment

terraform {
  backend "s3" {
    bucket       = "tofu-052941644876"
    key          = "ridelines-frame/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
