// Create private s3 bucket
resource "aws_s3_bucket" "terratest-bucket" {
    bucket = "${var.bucket_name}"
    acl    = "private"
    tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

// Set local timestamp to be imported in the 2 files.
locals {
  timestamp = "${timestamp()}"
}


// Create test1 into the bucket but wait for the bucket to be created first.
resource "aws_s3_bucket_object" "object1" {
    bucket = "${aws_s3_bucket.terratest-bucket.bucket}"
    key    = "test1.txt"
    acl = "private" 
    ontent = "${local.timestamp}"
    content_type = "text"
}

// Create test2 into the bucket but wait for the bucket to be created first.
resource "aws_s3_bucket_object" "object2" {
    bucket = "${aws_s3_bucket.terratest-bucket.bucket}"
    key    = "test2.txt"
    acl = "private"
    ontent = "${local.timestamp}"
    content_type = "text"
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [aws_s3_bucket_object.object2,aws_s3_bucket_object.object1]
  create_duration = "30s"
}


// Policy to allow access to IAM role and the user running Terraform and waits 30 seconds before creating to allow time for the objects to get uploaded to the bucket first.
resource "aws_s3_bucket_policy" "s3BucketPolicy" {
  bucket = "${var.bucket_name}"

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
