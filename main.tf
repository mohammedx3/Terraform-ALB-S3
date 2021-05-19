// Specify AWS region
provider "aws" {
  region = "eu-west-1" 
}

# resource "aws_s3_bucket" "tes" {
#   bucket = "my-tf-test-bucket-231923i12938"
#   acl    = "private"

#   tags = {
#     Name        = "My bucket"
#     Environment = "Dev"
#   }
# }


resource "aws_iam_role" "terraformS3" {
  name = "terraform_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "s3-policy"
  description = "S3 policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "terraform-policy-attach" {
  name       = "terraform-attach"
  roles      = [aws_iam_role.terraformS3.name]
  policy_arn = aws_iam_policy.policy.arn
}


data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}


data "aws_region" "current" {}

# locals {
#  az1 = "${data.aws_region.current.name}a"
#  az2 = "${data.aws_region.current.name}b"
# }


data "aws_availability_zones" "available" {
  state = "available"
}


resource "aws_vpc" "public" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
 tags = {
    Name = "Terraform VPC"
  }
}

resource "aws_subnet" "subnet_az1" {
  # count = 1
  map_public_ip_on_launch = true
  vpc_id     = aws_vpc.public.id
  # cidr_block = "10.20.20.0/24"
  cidr_block = "10.0.0.0/24"
  # availability_zone = "eu-west-1a"
  availability_zone= "${data.aws_availability_zones.available.names[0]}"
  # availability_zone= "${data.aws_availability_zones.available.names[count.index]}"
  tags = {
    Name = "Terraform Subnet az1"
  }
}

resource "aws_subnet" "subnet_az2" {
  #  count = 2
  map_public_ip_on_launch = false
  vpc_id     = aws_vpc.public.id
  # cidr_block = "10.20.20.0/24"
   cidr_block = "10.0.1.0/24"
  #  availability_zone = "eu-west-1b"
  availability_zone= "${data.aws_availability_zones.available.names[1]}"
  # availability_zone= "${data.aws_availability_zones.available.names[count.index]}"
  tags = {
    Name = "Terraform Subnet az2"
  }
}

// Create 2 text files and import timestamp in them
resource "local_file" "to_dir" {
  count    = "${length(local.source_files)}"
  filename = "./createdFiles/${basename(element(local.source_files, count.index))}"
  content  = "${local.timestamp}"
}

# // Specify variable with s3 bucket name
variable "bucket_name" {
  description = "The name of the bucket"
  default     = "task"
}

# // Set local timestamp to be imported in the 2 files.
locals {
  source_files = ["./createdFiles/test1.txt", "./createdFiles/test2.txt"]
  timestamp = "${timestamp()}"
}


# // Create private s3 bucket
resource "aws_s3_bucket" "terratest-bucket" {
  bucket = "terra-${var.bucket_name}"
  # acl    = "public-read"
    acl    = "private"
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

# // Import test1 into the bucket but wait for the bucket to be created first.
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
resource "time_sleep" "wait_30_seconds" {
  depends_on = [aws_s3_bucket_object.object2,aws_s3_bucket_object.object1]
  create_duration = "30s"
}



resource "aws_s3_bucket_policy" "s3BucketPolicy" {
  bucket = "terra-${var.bucket_name}"
  depends_on = [time_sleep.wait_30_seconds]
  # Terraform's "jsonencode" function converts a
  # Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "MYBUCKETPOLICY"
    Statement = [
    {
      "Effect": "Deny",
      # "Effect": "Allow",
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
            "111111111111"
          ]
        }
      }
    }
    ]
  })
}


# // Export bucket id to be later used in terratest.
# output "bucket_id" {
#   value = aws_s3_bucket.terratest-bucket.id
# }

