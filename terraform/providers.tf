terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.56.1"
    }
  }
}

provider "aws" {
  ######## set this to the same region as you did for packer ########
  region = "aa-example-1"
  ###################################################################
}