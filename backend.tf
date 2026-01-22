terraform {
  backend "s3" {
    bucket         = "terraform-state-test29"
    key            = "vpc/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
