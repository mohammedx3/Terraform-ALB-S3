variable "iamrole_name" {
  description = "The name of the IAM role"
  default     = "task"
}

variable "iamrole_policy_name" {
  description = "The name of the IAM role policy"
  default     = "task"
}

// Create IAM role.
resource "aws_iam_role" "terraformS3" {
  name = "terraform_role-${var.iamrole_name}"

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

// IAM role policy has only access to S3 services.
resource "aws_iam_policy" "policy" {
  name        = "Allow-S3-Policy-${var.iamrole_policy_name}"
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

// Attach policy to IAM role.
resource "aws_iam_policy_attachment" "terraform-policy-attach" {
  name       = "terraform-attach"
  roles      = [aws_iam_role.terraformS3.name]
  policy_arn = aws_iam_policy.policy.arn
}
