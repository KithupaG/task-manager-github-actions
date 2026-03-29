terraform {
  backend "s3" {
    bucket         = "myapp-terraform-state-kithupag"
    key            = "eks/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}