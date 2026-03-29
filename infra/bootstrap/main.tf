provider "aws" {
    region = "ap-southeast-1"
}

resource "aws_s3_bucket" "terraform_state" {
    bucket = "myapp-terraform-state-kithupag"

    lifecycle {
        prevent_destroy = true
    }

    tags = {
        Name = "Terraform State"
    }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
    bucket = aws_s3_bucket.terraform_state.id
    versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_dynamodb_table" "basic-dynamodb-table" {
    name = "terraform-state-lock"
    hash_key = "LockID"
    billing_mode   = "PAY_PER_REQUEST"

    attribute {
        name = "LockID"
        type = "S"
    }

    tags = {
        Name = "dynamodb-table"
    }
}