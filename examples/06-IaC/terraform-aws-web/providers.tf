terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Production Best Practice: Remote State Backend
  # (Commented out for local testing, but required for enterprise)
  /*
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "web-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
  */
}

provider "aws" {
  region = var.aws_region

  # Default tags applied to ALL resources created by this provider
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "GodMode-Vault"
    }
  }
}
