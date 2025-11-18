terraform {
  required_version = ">= 1.6.0"
  backend "s3" {
    bucket         = "saas-marketplace-terraform-state-077045714239"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "saas-marketplace-terraform-locks"
  }
}