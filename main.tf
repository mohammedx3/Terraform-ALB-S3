provider "aws" {
  region = "eu-west-1"
  access_key = "${{ secrets.AWS_ACCESS_KEY_ID }}"
  secret_key = "${{ secrets.AWS_SECRET_ACCESS_KEY }}"
}



resource "local_file" "to_dir" {
  count    = "${length(local.source_files)}"
  filename = "${path.module}/createdFiles/${basename(element(local.source_files, count.index))}"
  content  = "${local.timestamp}"
}

variable "bucket_name" {
  description = "The name of the bucket"
  default     = "terratest-task-s3"
}


locals {
  source_files = ["${path.module}/createdFiles/file1.txt", "${path.module}/createdFiles/file2.txt"]
  timestamp = "${timestamp()}"
}


resource "aws_s3_bucket" "terratest-bucket" {
  bucket = "${var.bucket_name}"
  acl    = "public-read"
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


resource "aws_s3_bucket_object" "object1" {
  bucket = "${var.bucket_name}"
  key    = "file1.txt"
  acl = "public-read"
  source = "${path.module}/createdFiles/file1.txt"
  depends_on = [
    aws_s3_bucket.terratest-bucket
  ]
}


resource "aws_s3_bucket_object" "object2" {
  bucket = "${var.bucket_name}"
  key    = "file2.txt"
  acl = "public-read"
  source = "${path.module}/createdFiles/file2.txt"
  depends_on = [
    aws_s3_bucket.terratest-bucket
  ]
}


output "bucket_id" {
  value = aws_s3_bucket.terratest-bucket.id
}

