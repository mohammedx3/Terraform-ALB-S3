// default AWS region.
provider "aws" {
  region = var.aws_region
}

// Creating autoscalling group that has 2 instances with max size of 2, the same launch configuration and healthcheck in both subnets in both availability zones.
resource "aws_autoscaling_group" "web_servers" {

  name = aws_launch_configuration.web_servers.name
  launch_configuration = aws_launch_configuration.web_servers.name
  min_size         = 1
  max_size         = 2
  desired_capacity = 2

// Deploy into all the subnets (and therefore AZs) available
  vpc_zone_identifier = [aws_subnet.subnet_az1.id,aws_subnet.subnet_az2.id]

// Automatically register this ASG's Instances in the ALB and use the ALB's health check to determine when an Instance
// needs to be replaced
  health_check_type = "ELB"
  target_group_arns = [aws_alb_target_group.web_servers.arn]

  tag {
    key                 = "Name"
    value               = var.instance_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

// Wait for atleast one listener to be able to do the health checks.
  depends_on = [aws_alb_listener.http]
}

// Launch confiugration template for the EC2 Instances that has the needed configuration set.
resource "aws_launch_configuration" "web_servers" {
  image_id        = "ami-0a8e758f5e873d1c1"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.web_server.id]
  user_data       = data.template_file.user_data.rendered
  iam_instance_profile = aws_iam_instance_profile.terraform_profile.name
  key_name        = var.key_pair_name
  lifecycle {
    create_before_destroy = true
  }
}

// Template to run bash script during boot, the script will install the updated packages, awscli, Traefik, create presign URLs for the files in the bucket.
//  Create the Traefik config files that will be used by Traefik to do the reverse proxy, and start Traefik.
data "template_file" "user_data" {
  template = file("${path.module}/user-data/user-data.sh")

  vars = {
    # instance_text = var.instance_text
    instance_port = var.instance_port
    s3_name = "${aws_s3_bucket.terratest-bucket.bucket}"
  }
}

// Creating the security group for the web servers.
resource "aws_security_group" "web_server" {
  name   = var.instance_name
  vpc_id = aws_vpc.public.id
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_vpc.public
  ]
}

// Adding security group rule to allow traffic coming on port 80.
resource "aws_security_group_rule" "web_server_allow_http_inbound" {
  type              = "ingress"
  from_port         = var.instance_port
  to_port           = var.instance_port
  protocol          = "tcp"
  security_group_id = aws_security_group.web_server.id
  cidr_blocks       = ["0.0.0.0/0"]
}

// Another rule to allow ssh connections so we can debug if something goes wrong.
resource "aws_security_group_rule" "web_server_allow_ssh_inbound" {
  type              = "ingress"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  security_group_id = aws_security_group.web_server.id
  cidr_blocks       = ["0.0.0.0/0"]
}

// Allow all outbound traffic.
resource "aws_security_group_rule" "web_server_allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.web_server.id
  cidr_blocks       = ["0.0.0.0/0"]
}

// Creating load balancer to distribute traffic to ASG.
resource "aws_alb" "web_servers" {
  name            = var.instance_name
  security_groups = [aws_security_group.alb.id]
  subnets         = [aws_subnet.subnet_az1.id,aws_subnet.subnet_az2.id]
  lifecycle {
    create_before_destroy = true
  }
}

// Creating a load balancer listener on HTTP.
resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.web_servers.arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.web_servers.arn
  }

  lifecycle {
    create_before_destroy = true
  }
}

// ALB target group that will perform health checks on the EC2 instaces.
resource "aws_alb_target_group" "web_servers" {
  depends_on = [aws_alb.web_servers]

  name     = var.instance_name
  port     = var.instance_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.public.id

// Health check intervals on the instances.
  deregistration_delay = 10

  health_check {
    path                = "/"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  lifecycle {
    create_before_destroy = true
  }
}

// The ALB listener rule will forward all requests to ASG.
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

// Security group for the load balancer.
resource "aws_security_group" "alb" {
  name   = "${var.instance_name}-alb"
  vpc_id = aws_vpc.public.id
}

// Allow traffic on port 80.
resource "aws_security_group_rule" "alb_allow_http_inbound" {
  type              = "ingress"
  from_port         = var.alb_port
  to_port           = var.alb_port
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

// Allowing all traffic coming out of the load balancer to be able to perform the health checks.
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}