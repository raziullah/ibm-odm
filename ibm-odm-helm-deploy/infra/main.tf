# AWS region and account context are shared by infrastructure resources.
provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
