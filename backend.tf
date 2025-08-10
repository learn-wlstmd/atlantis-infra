terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.8.0"
    }
  }
  backend "s3" {
    bucket = "wlstmd-atlantis-tfstate"
    key    = "terraform-backend/terraform.tfstate"
    region = "ap-northeast-2"
    dynamodb_table = "terraform-locks"
    profile = "wlstmd"
  }
}