# Step 2: tells the main lab project to store its state in the bucket.
# Run: terraform init

terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "keith-mccarthy-tf-state-lab"
    key          = "lab/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true # native S3 state locking, no DynamoDB table needed
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}
