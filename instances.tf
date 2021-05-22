# # // Specify AWS region
# provider "aws" {
#   region = "eu-west-1" 
# }


# data "aws_region" "current" {}

# variable "profile_name" {
#   description = "The name of the IAM role"
#   default     = "task"
# }

# variable "alb_name" {
#   description = "The name of the IAM role"
#   default     = "task"
# }

# variable "group_name" {
#   description = "The name of the IAM role"
#   default     = "task"
# }

# variable "lbsg_name" {
#   description = "The name of the IAM role"
#   default     = "task"
# }

# // Specify  profile for the ec2 instance
# resource "aws_iam_instance_profile" "terraform_profile" {
#   name = "terraform_profile-${var.profile_name}"
#   role = "${aws_iam_role.terraformS3.name}"
# }

# // Create the instances that will host Traefik, and run the needed commands on boot to set it up and run it.
# resource "aws_instance" "firstInstance" {
#   ami = "ami-0a8e758f5e873d1c1"
#   instance_type = "t2.micro"
#   iam_instance_profile = "${aws_iam_instance_profile.terraform_profile.name}"
#   private_ip = "10.0.1.10"
#   subnet_id = aws_subnet.subnet_az2.id
#   security_groups    = [aws_security_group.lb_sg.id]
#   key_name = "testtask"
#      user_data = <<-EOL
    # #!/bin/bash -xe

    # sudo apt update -y
    # cd /home/ubuntu
    # sudo wget https://github.com/traefik/traefik/releases/download/v1.7.30/traefik_linux-amd64
    # sudo chmod 777 traefik_linux-amd64
    # mkdir configs

    # apt install awscli -y

    # echo -e '[frontends] \n [frontends.frontend1] \n backend = "backend1" \n  [frontends.frontend1.routes.playgrond] \n  rule = "PathPrefix:/" \n \n[backends] \n  [backends.backend1] \n   [backends.backend1.servers.server1] \n   url = "http://${aws_s3_bucket.terratest-bucket.bucket}.s3-eu-west-1.amazonaws.com"' > configs/reverse.toml
    # echo -e 'logLevel = "DEBUG" \ndebug=true \ndefaultEntryPoints = ["http"] \n \n[file] \n directory = "/home/ubuntu/configs" \n watch = true \n[entryPoints] \n [entryPoints.http] \n   address = ":80" \n[traefikLog] \n  filePath = "./traefik.log"' > traefik.toml 
    # ./traefik_linux-amd64
    # EOL
#   tags = {
#     Name = var.instance_name1
#   }
# }


# variable "instance_name1" {
#   description = "The Name tag to set for the EC2 Instance."
#   type        = string
#   default     = "First Instance"
# }

# variable "instance_type1" {
#   description = "The EC2 instance type to run."
#   type        = string
#   default     = "t2.micro"
# }

# variable "instance_name2" {
#   description = "The Name tag to set for the EC2 Instance."
#   type        = string
#   default     = "Second Instance"
# }

# variable "instance_type2" {
#   description = "The EC2 instance type to run."
#   type        = string
#   default     = "t2.micro"
# }

# output "instance_id1" {
#     value = "${aws_instance.firstInstance.id}"
# }

# output "instance_id2" {
#     value = "${aws_instance.secondInstance.id}"
# }

# resource "aws_instance" "secondInstance" {
#   ami = "ami-0a8e758f5e873d1c1"
#   instance_type = "t2.micro"
#   iam_instance_profile = "${aws_iam_instance_profile.terraform_profile.name}"
#   subnet_id = aws_subnet.subnet_az1.id
#   security_groups    = [aws_security_group.lb_sg.id]
#   key_name = "testtask"
#      user_data = <<-EOL
#     #!/bin/bash -xe
#     sudo apt update -y
#     cd /home/ubuntu
#     sudo wget https://github.com/traefik/traefik/releases/download/v1.7.30/traefik_linux-amd64
#     sudo chmod 777 traefik_linux-amd64
#     mkdir configs
   
#     apt install awscli -y
    
#     echo -e '[frontends] \n [frontends.frontend1] \n backend = "backend1" \n  [frontends.frontend1.routes.playgrond] \n  rule = "PathPrefix:/" \n \n[backends] \n  [backends.backend1] \n   [backends.backend1.servers.server1] \n   url = "http://${aws_s3_bucket.terratest-bucket.bucket}.s3-eu-west-1.amazonaws.com"' > configs/reverse.toml
#     echo -e 'logLevel = "DEBUG" \ndebug=true \ndefaultEntryPoints = ["http"] \n \n[file] \n directory = "/home/ubuntu/configs" \n watch = true \n[entryPoints] \n [entryPoints.http] \n   address = ":80" \n[traefikLog] \n  filePath = "./traefik.log"' > traefik.toml 
#     ./traefik_linux-amd64
#     EOL
#   tags = {
#     Name = var.instance_name2
#   }
# }

# # // Create the load balancer that will redirect the requests to the instances.
# # resource "aws_lb" "TerraformALB" {
# #   name               = "S3-ALB-${var.alb_name}"
# #   internal           = false
# #   load_balancer_type = "application"
# #   security_groups    = [aws_security_group.lb_sg.id]
# #   subnets            = [aws_subnet.subnet_az1.id,aws_subnet.subnet_az2.id]
# #   enable_cross_zone_load_balancing = true
# #   tags = {
# #     Environment = "production"
# #   }
# # }

# # // Loadbalancer security group to allow all traffic for the purpose of testing.

# resource "aws_security_group" "lb_sg" {
#   name        = "allow_traffic-${var.lbsg_name}"
#   description = "all traffic for testing"
#   vpc_id      = aws_vpc.public.id

#   ingress {
#     description      = "Allow all traffic"
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]

#   }

#   egress {
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "allow_traffic"
#   }
# }

# //Specify load balancer target group and attach them to it.
# resource "aws_lb_target_group" "LBTargetGroup" {
#   name     = "LBGroup-a${var.group_name}"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.public.id
#   target_type = "instance"
# }

# resource "aws_lb_target_group_attachment" "attach1" {
#   target_group_arn = aws_lb_target_group.LBTargetGroup.arn
#   target_id        = aws_instance.firstInstance.id
#   port             = 80
# }
# resource "aws_lb_target_group_attachment" "attach2" {
#   target_group_arn = aws_lb_target_group.LBTargetGroup.arn
#   target_id        = aws_instance.secondInstance.id
#   port             = 80
# }

# // Listen on port 80.
# resource "aws_lb_listener" "front_end" {
#   load_balancer_arn = aws_lb.TerraformALB.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.LBTargetGroup.arn
#   }
# }


