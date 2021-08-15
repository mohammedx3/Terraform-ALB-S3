// Create IAM role.
resource "aws_iam_role" "terraformS3" {
  name = "terraform_role-${var.iam_name}"

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

// Create profile for the IAM.
resource "aws_iam_instance_profile" "terraform_profile" {
  name = "terraform_profile-${var.profile_name}"
  role = "${aws_iam_role.terraformS3.name}"
}

// IAM role policy has access to only S3 services.
resource "aws_iam_policy" "policy" {
  name        = "Allow-S3-Policy-${var.iam_policy_name}"
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