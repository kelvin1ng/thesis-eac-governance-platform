# CHAPTER3_REFERENCE.md §3.2.1 Layer 1, Table 1: Terraform backend
# State storage and locking per HashiCorp guidance [5]. Immutability: state history, apply logs.
# Use: terraform init -backend-config=backend.hcl
# Create S3 bucket first (see infra/README.md). This update addresses a Terraform deprecation warning:
# dynamodb_table is deprecated in favor of use_lockfile (native S3 locking; Terraform 1.10+).

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "thesis-eac-tfstate"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    profile      = "thesis"
    encrypt      = true
  }
}
