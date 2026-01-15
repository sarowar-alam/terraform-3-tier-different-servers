terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    # S3 bucket name will be provided via backend config file or -backend-config flag
    # bucket         = "your-terraform-state-bucket"
    key     = "bmi-health-tracker/terraform.tfstate"
    region  = "ap-south-1" # Update to your region
    encrypt = true
    # dynamodb_table = "terraform-state-lock" # Optional: for state locking
    # profile        = "your-aws-profile"     # AWS CLI named profile
  }
}
