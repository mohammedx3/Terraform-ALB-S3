// ---------------------------------- NETWORKS VARIABLES ----------------------------------

variable "main_vpc_cidr" {
  description = "The CIDR of the main VPC"
  type        = string
  default = "10.0.0.0/16"
}

variable "first_subnet_cidr" {
  description = "The CIDR of first public subnet"
  type        = string
  default = "10.0.0.0/24"
}

variable "second_subnet_cidr" {
  description = "The CIDR of second public subnet"
  type        = string
  default = "10.0.1.0/24"
}


// ---------------------------------- S3 VARIABLES ----------------------------------

variable "bucket_name" {
  description = "The name of the bucket"
  default     = "task"
}

variable "bucketpolicy_name" {
  description = "The name of the bucket"
  default     = "task"
}

// ---------------------------------- IAM ROLE VARIABLES ----------------------------------

variable "profile_name" {
  description = "The name of the IAM role"
  default     = "task"
}

variable "iamrole_name" {
  description = "The name of the IAM role"
  default     = "task"
}

variable "iamrole_policy_name" {
  description = "The name of the IAM role policy"
  default     = "task"
}

// ---------------------------------- INSTANCE VARIABLES ----------------------------------

variable "aws_region" {
  description = "The AWS region to deploy into (e.g. us-east-1)."
  type        = string
  default     = "eu-west-1"
}

variable "instance_name" {
  description = "The names for the ASG and other resources in this module"
  type        = string
  default     = "Terraform-ALB"
}

variable "instance_port" {
  description = "The port each EC2 Instance should listen on for HTTP requests."
  type        = number
  default     = 80
}

variable "ssh_port" {
  description = "The port each EC2 Instance should listen on for SSH requests."
  type        = number
  default     = 22
}

variable "instance_text" {
  description = "The text each EC2 Instance should return when it gets an HTTP request."
  type        = string
  default     = "Hello, World!"
}

variable "alb_port" {
  description = "The port the ALB should listen on for HTTP requests"
  type        = number
  default     = 80
}

variable "key_pair_name" {
  description = "The EC2 Key Pair to associate with the EC2 Instance for SSH access."
  type        = string
  default     = "testtask"
}

variable "instance_type" {
  description = "The EC2 instance type to run."
  type        = string
  default     = "t2.micro"
}