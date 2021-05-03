provider "aws" {
  profile = var.profile
  region  = var.region
}

terraform {
  required_version = ">= 0.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.38.0"
    }
  }

  backend "s3" {}
}
