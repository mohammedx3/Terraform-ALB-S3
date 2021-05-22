provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_group" "web_servers" {
  # Note that we intentionally depend on the Launch Configuration name so that creating a new Launch Configuration
  # (e.g. to deploy a new AMI) creates a new Auto Scaling Group. This will allow for rolling deployments.
  name = aws_launch_configuration.web_servers.name

  launch_configuration = aws_launch_configuration.web_servers.name
  min_size         = 1
  max_size         = 2
  desired_capacity = 2
#   min_elb_capacity = 2

  # Deploy into all the subnets (and therefore AZs) available
  vpc_zone_identifier = [aws_subnet.subnet_az1.id,aws_subnet.subnet_az2.id]

  # Automatically register this ASG's Instances in the ALB and use the ALB's health check to determine when an Instance
  # needs to be replaced
  health_check_type = "ELB"

  target_group_arns = [aws_alb_target_group.web_servers.arn]

  tag {
    key                 = "Name"
    value               = var.instance_name
    propagate_at_launch = true
  }

  # To support rolling deployments, we tell Terraform to create a new ASG before deleting the old one. Note: as
  # soon as you set create_before_destroy = true in one resource, you must also set it in every resource that it
  # depends on, or you'll get an error about cyclic dependencies (especially when removing resources).
  lifecycle {
    create_before_destroy = true
  }

  # This needs to be here to ensure the ALB has at least one listener rule before the ASG is created. Otherwise, on the
  # very first deployment, the ALB won't bother doing any health checks, which means min_elb_capacity will not be
  # achieved, and the whole deployment will fail.
  depends_on = [aws_alb_listener.http]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE LAUNCH CONFIGURATION
# This is a "template" that defines the configuration for each EC2 Instance in the ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "web_servers" {
  image_id        = "ami-0a8e758f5e873d1c1"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.web_server.id]
  user_data       = data.template_file.user_data.rendered
  iam_instance_profile = aws_iam_instance_profile.terraform_profile.name
#   key_name        = var.key_pair_name
  key_name = "testtask"

  # When used with an aws_autoscaling_group resource, the aws_launch_configuration must set create_before_destroy to
  # true. Note: as soon as you set create_before_destroy = true in one resource, you must also set it in every resource
  # that it depends on, or you'll get an error about cyclic dependencies (especially when removing resources).
  lifecycle {
    create_before_destroy = true
  }
}



# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN DURING BOOT ON THE EC2 INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data" {
  template = file("${path.module}/user-data/user-data.sh")

  vars = {
    # instance_text = var.instance_text
    instance_port = var.instance_port
    s3_name = aws_s3_bucket.terratest-bucket.bucket
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# FOR THIS EXAMPLE, WE JUST RUN A PLAIN UBUNTU 16.04 AMI
# ---------------------------------------------------------------------------------------------------------------------

# data "aws_ami" "ubuntu" {
#   most_recent = true
#   owners      = ["099720109477"] # Canonical

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   filter {
#     name   = "architecture"
#     values = ["x86_64"]
#   }

#   filter {
#     name   = "image-type"
#     values = ["machine"]
#   }

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
#   }
# }

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO CONTROL WHAT TRAFFIC CAN GO IN AND OUT OF THE EC2 INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "web_server" {
  name   = var.instance_name
  vpc_id = aws_vpc.public.id


  # This is here because aws_launch_configuration.web_servers sets create_before_destroy to true and depends on this
  # resource
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_vpc.public
  ]
}

resource "aws_security_group_rule" "web_server_allow_http_inbound" {
  type              = "ingress"
  from_port         = var.instance_port
  to_port           = var.instance_port
  protocol          = "tcp"
  security_group_id = aws_security_group.web_server.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web_server_allow_ssh_inbound" {
  type              = "ingress"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  security_group_id = aws_security_group.web_server.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web_server_allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.web_server.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB TO DISTRIBUTE TRAFFIC ACROSS THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb" "web_servers" {
  name            = var.instance_name
  security_groups = [aws_security_group.alb.id]
  subnets         = [aws_subnet.subnet_az1.id,aws_subnet.subnet_az2.id]

  # This is here because aws_alb_listener.http depends on this resource and sets create_before_destroy to true
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB LISTENER FOR HTTP REQUESTS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.web_servers.arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.web_servers.arn
  }

  # This is here because aws_autoscaling_group.web_servers depends on this resource and sets create_before_destroy
  # to true
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB TARGET GROUP FOR THE ASG
# This target group will perform health checks on the web servers in the ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_target_group" "web_servers" {
  depends_on = [aws_alb.web_servers]

  name     = var.instance_name
  port     = var.instance_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.public.id

  # Give existing connections 10 seconds to complete before deregistering an instance. The default delay is 300 seconds
  # (5 minutes), which significantly slows down redeploys. In theory, the ALB should deregister the instance as long as
  # there are no open connections; in practice, it waits the full five minutes every time. If your requests are
  # generally processed quickly, set this to something lower (such as 10 seconds) to keep redeploys fast.
  deregistration_delay = 10

  health_check {
    path                = "/"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  # This is here because aws_autoscaling_group.web_servers depends on this resource and sets create_before_destroy
  # to true
  lifecycle {
    create_before_destroy = true
  }
}

# Create a new ALB Target Group attachment
# resource "aws_autoscaling_attachment" "asg_attachment_bar" {
#   autoscaling_group_name = aws_autoscaling_group.web_servers.id
#   alb_target_group_arn   = aws_iam_role.terraformS3.arn
# }

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB LISTENER RULE TO SEND ALL REQUESTS TO THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_listener_rule" "send_all_to_web_servers" {
  listener_arn = aws_alb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.web_servers.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO CONTROL WHAT TRAFFIC CAN GO IN AND OUT OF THE ALB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name   = "${var.instance_name}-alb"
  vpc_id = aws_vpc.public.id
}

resource "aws_security_group_rule" "alb_allow_http_inbound" {
  type              = "ingress"
  from_port         = var.alb_port
  to_port           = var.alb_port
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# We need to allow outbound connections from the ALB so it can perform health checks
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY INTO THE DEFAULT VPC AND SUBNETS
# To keep this example simple, we are deploying into the Default VPC and its subnets. In real-world usage, you should
# deploy into a custom VPC and private subnets.
# ---------------------------------------------------------------------------------------------------------------------

# variable "vpc_id" {
#     default = "10.0.0.0/16"
# }

# data "aws_vpc" "default" {
#   id = var.vpc_id
# }

# data "aws_subnet_ids" "default" {
# #   vpc_id = data.aws_vpc.public.id
#  vpc_id = var.vpc_id
# }

output "alb_dns_name" {
  value = aws_alb.web_servers.dns_name
}

output "url" {
  value = "http://${aws_alb.web_servers.dns_name}:${var.alb_port}"
}

output "asg_name" {
  value = aws_autoscaling_group.web_servers.name
}

variable "aws_region" {
  description = "The AWS region to deploy into (e.g. us-east-1)."
  type        = string
  default     = "eu-west-1"
}

variable "instance_name" {
  description = "The names for the ASG and other resources in this module"
  type        = string
  default     = "asg-alb-example"
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

# variable "instance_text" {
#   description = "The text each EC2 Instance should return when it gets an HTTP request."
#   type        = string
#   default     = "Hello, World!"
# }

variable "alb_port" {
  description = "The port the ALB should listen on for HTTP requests"
  type        = number
  default     = 80
}

variable "key_pair_name" {
  description = "The EC2 Key Pair to associate with the EC2 Instance for SSH access."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "The EC2 instance type to run."
  type        = string
  default     = "t2.micro"
}