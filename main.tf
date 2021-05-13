// Specify AWS region
provider "aws" {
  region = "eu-west-1" 

}

// Create 2 text files and import timestamp in them
resource "local_file" "to_dir" {
  count    = "${length(local.source_files)}"
  filename = "./createdFiles/${basename(element(local.source_files, count.index))}"
  content  = "${local.timestamp}"
}

// Specify variable with s3 bucket name
variable "bucket_name" {
  description = "The name of the bucket"
  default     = "task"
}

// Set local timestamp to be imported in the 2 files.
locals {
  source_files = ["./createdFiles/test1.txt", "./createdFiles/test2.txt"]
  timestamp = "${timestamp()}"
}


// Create private s3 bucket
resource "aws_s3_bucket" "terratest-bucket" {
  bucket = "terra-${var.bucket_name}"
  # acl    = "public-read"
    acl    = "private"
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

// Import test1 into the bucket but wait for the bucket to be created first.
resource "aws_s3_bucket_object" "object1" {
  bucket = "terra-${var.bucket_name}"
  key    = "test1.txt"
  # acl = "public-read"
    acl = "private"
  source = "./createdFiles/test1.txt"
  depends_on = [
    aws_s3_bucket.terratest-bucket
  ]
}

// Import test2 into the bucket but wait for the bucket to be created first.
resource "aws_s3_bucket_object" "object2" {
  bucket = "terra-${var.bucket_name}"
  key    = "test2.txt"
  # acl = "public-read"
    acl = "private"
  source = "./createdFiles/test2.txt"
  depends_on = [ 
    aws_s3_bucket.terratest-bucket
  ]
}

// Export bucket id to be later used in terratest.
output "bucket_id" {
  value = aws_s3_bucket.terratest-bucket.id
}

