terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # TODO: replace with your real state bucket before running init/plan/apply.
    bucket       = "REPLACE-ME-alb-ec2-rds-tfstate"
    key          = "alb-ec2-rds-stack/dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # S3 native locking (Terraform >= 1.10) — no DynamoDB table needed
  }
}

provider "aws" {
  region = var.region
}
