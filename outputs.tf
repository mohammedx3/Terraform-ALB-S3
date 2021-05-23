// ---------------------------------- NETWORKS OUTPUTS ----------------------------------

output "main_vpc_id" {
  value       = aws_vpc.public.id
  description = "The public VPC id"
}

output "public1_subnet_id" {
  value       = aws_subnet.subnet_az1.id
  description = "The first public subnet id"
}

output "public2_subnet_id" {
  value       = aws_subnet.subnet_az2.id
  description = "The second public subnet id"
}


// ---------------------------------- S3 OUTPUTS ----------------------------------

output "bucket_id" {
  value = aws_s3_bucket.terratest-bucket.id
}

output "bucket_name" {
  value = aws_s3_bucket.terratest-bucket
}

output "time_stamp" {
  value = "${local.timestamp}"
}

// ---------------------------------- IAM ROLE OUTPUTS ----------------------------------

output "profile_name" {
    value = aws_iam_instance_profile.terraform_profile.name
}

output "iam_name" {
    value = aws_iam_role.terraformS3.name
}
output "iam_policy_name" {
    value = aws_iam_policy.policy.name
}

output "iam_policy_attach" {
    value = aws_iam_policy_attachment.terraform-policy-attach.name
}

// ---------------------------------- INSTANCE OUTPUTS ----------------------------------

output "alb_dns_name" {
   value = aws_alb.web_servers.dns_name
}

output "url" {
   value = "http://${aws_alb.web_servers.dns_name}:${var.alb_port}"
}

output "asg_name" {
  value = aws_autoscaling_group.web_servers.name
}