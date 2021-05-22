// Specify variable with s3 bucket name
variable "bucket_name" {
  description = "The name of the bucket"
  default     = "task"
}

variable "bucketpolicy_name" {
  description = "The name of the bucket"
  default     = "task"
}

// Create private s3 bucket
resource "aws_s3_bucket" "terratest-bucket" {
    bucket = "terra-${var.bucket_name}"
    acl    = "private"
    tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

// Create 2 text files and import timestamp in them
resource "local_file" "to_dir" {
  count    = "${length(local.source_files)}"
  filename = "./createdFiles/${basename(element(local.source_files, count.index))}"
  content  = "${local.timestamp}"
}


// Set local timestamp to be imported in the 2 files.
locals {
  source_files = ["./createdFiles/test1.txt", "./createdFiles/test2.txt"]
  timestamp = "${timestamp()}"
}


// Import test1 into the bucket but wait for the bucket to be created first.
resource "aws_s3_bucket_object" "object1" {
    bucket = "terra-${var.bucket_name}"
    key    = "test1.txt"
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
    acl = "private"
    source = "./createdFiles/test2.txt"
    depends_on = [ 
    aws_s3_bucket.terratest-bucket
    ]
}


resource "time_sleep" "wait_30_seconds" {
  depends_on = [aws_s3_bucket_object.object2,aws_s3_bucket_object.object1]
  create_duration = "30s"
}


// Policy to allow access to IAM role and the user running Terraform and waits 30 seconds before creating to allow time for the objects to get uploaded to the bucket first.
resource "aws_s3_bucket_policy" "s3BucketPolicy" {
  bucket = "terra-${var.bucket_name}"

  depends_on = [time_sleep.wait_30_seconds,aws_s3_bucket.terratest-bucket]
  # Terraform's "jsonencode" function converts a
  # Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "MYBUCKETPOLICY-${var.bucket_name}"
    Statement = [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
            aws_s3_bucket.terratest-bucket.arn,
          "${aws_s3_bucket.terratest-bucket.arn}/*",
      ],
      "Condition": {
        "StringNotLike": {
            "aws:userId": [
            "${aws_iam_role.terraformS3.unique_id}:*",
            "AIDAQFAEZHF3L7RQQ2NE3"
          ]
        }
      }
    }
    ]
  })
}


// Export bucket id to be later used in terratest.
output "bucket_id" {
  value = aws_s3_bucket.terratest-bucket.id
}

output "bucket_name" {
  value = aws_s3_bucket.terratest-bucket
}


output "time_stamp" {
  value = local.timestamp
}