provider "aws" {
region = "us-east-2"
}

resource "aws_s3_bucket" "terraform_state" {
bucket = "terraform-up-and-running-state-day5"
# Prevent accidental deletion of this S3 bucket
lifecycle {
prevent_destroy = true
}
}

# Enable versioning so you can see the full revision history of your
# state files
resource "aws_s3_bucket_versioning" "enabled" {
bucket = aws_s3_bucket.terraform_state.id
versioning_configuration {
status = "Enabled"
}
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
bucket = aws_s3_bucket.terraform_state.id
rule {
apply_server_side_encryption_by_default {
sse_algorithm = "AES256"
}
}
}

#To use DynamoDB for locking with Terraform, you must create a DynamoDB table
#that has a primary key called LockID (with this exact spelling and capitalization). You
#can create such a table using the aws_dynamodb_table resource:

resource "aws_dynamodb_table" "terraform_locks" {
        name= "terraform-up-and-running-locks"
        billing_mode = "PAY_PER_REQUEST"
        hash_key= "LockID"
        attribute {
                name = "LockID"
                type = "S"
        }
}

#Run terraform init to download the provider code, and then run terraform apply
#to deploy. After everything is deployed, you will have an S3 bucket and DynamoDB
#table, but your Terraform state will still be stored locally. To configure Terraform to
#store the state in your S3 bucket (with encryption and locking), you need to add a
#backend configuration to your Terraform code. This is configuration for Terraform
#itself, so it resides within a terraform block and has the following syntax:
