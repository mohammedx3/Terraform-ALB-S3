# // Specify AWS region
provider "aws" {
  region = "eu-west-1" 
}


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


# data "aws_iam_policy_document" "instance-assume-role-policy" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["s3.amazonaws.com"]
#     }
#   }
# }


data "aws_region" "current" {}



data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.public.id

  tags = {
    Name = "main"
  }
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
  map_public_ip_on_launch = true
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

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.public.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Route table"
  }
}

resource "aws_main_route_table_association" "routeassoci" {
  vpc_id         = aws_vpc.public.id
  route_table_id = aws_route_table.route.id
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
    force_destroy = true
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
  lifecycle {
  create_before_destroy = true
}
  depends_on = [time_sleep.wait_30_seconds,aws_s3_bucket.terratest-bucket]
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



data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
    filter {
       name   = "architecture"
       values = ["x86_64"]
     }
  owners = ["099720109477"] 
}

resource "aws_iam_instance_profile" "terraform_profile" {
  name = "terraform_profile"
  role = "${aws_iam_role.terraformS3.name}"
}


resource "aws_instance" "firstInstance" {
  # ami           = data.aws_ami.ubuntu.id
  ami = "ami-0a8e758f5e873d1c1"
  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.terraform_profile.name}"
  private_ip = "10.0.1.10"
  subnet_id = aws_subnet.subnet_az2.id
  security_groups    = [aws_security_group.lb_sg.id]
  key_name = "testtask"
     user_data = <<-EOL
    #!/bin/bash -xe

    cd /home/ubuntu
    sudo wget https://github.com/traefik/traefik/releases/download/v1.7.30/traefik_linux-amd64
    sudo chmod 777 traefik_linux-amd64
    mkdir configs
    echo -e '[frontends] \n [frontends.frontend1] \n backend = "backend1" \n  [frontends.frontend1.routes.playgrond] \n  rule = "PathPrefix:/" \n \n[backends] \n  [backends.backend1] \n   [backends.backend1.servers.server1] \n   url = "http://google.com"' > configs/reverse.toml
    echo -e 'logLevel = "DEBUG" \ndebug=true \ndefaultEntryPoints = ["http"] \n \n[file] \n directory = "/home/ubuntu/configs" \n watch = true \n[entryPoints] \n [entryPoints.http] \n   address = ":80" \n[traefikLog] \n  filePath = "./traefik.log"' > traefik.toml 
    ./traefik_linux-amd64
    EOL
  tags = {
    Name = "First Instance"
  }
}

resource "aws_instance" "secondInstance" {
  # ami           = data.aws_ami.ubuntu.id
  ami = "ami-0a8e758f5e873d1c1"

  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.terraform_profile.name}"
  subnet_id = aws_subnet.subnet_az1.id
  security_groups    = [aws_security_group.lb_sg.id]
  key_name = "testtask"
     user_data = <<-EOL
    #!/bin/bash -xe

    cd /home/ubuntu
    sudo wget https://github.com/traefik/traefik/releases/download/v1.7.30/traefik_linux-amd64
    sudo chmod 777 traefik_linux-amd64
    mkdir configs
    echo -e '[frontends] \n [frontends.frontend1] \n backend = "backend1" \n  [frontends.frontend1.routes.playgrond] \n  rule = "PathPrefix:/" \n \n[backends] \n  [backends.backend1] \n   [backends.backend1.servers.server1] \n   url = "http://google.com"' > configs/reverse.toml
    echo -e 'logLevel = "DEBUG" \ndebug=true \ndefaultEntryPoints = ["http"] \n \n[file] \n directory = "/home/ubuntu/configs" \n watch = true \n[entryPoints] \n [entryPoints.http] \n   address = ":80" \n[traefikLog] \n  filePath = "./traefik.log"' > traefik.toml 
    ./traefik_linux-amd64
    EOL
  tags = {
    Name = "Second Instance"
  }
}


resource "aws_security_group" "lb_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.public.id

  ingress {
    description      = "Allow all traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_lb" "TerraformALB" {
  name               = "S3-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.subnet_az1.id,aws_subnet.subnet_az2.id]
  # instances = ["${aws_instance.firstInstance.id,aws_instance.secondInstance.id}"]
  enable_cross_zone_load_balancing = true
  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "LBTargetGroup" {
  name     = "LBGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.public.id
  target_type = "instance"
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.LBTargetGroup.arn
  target_id        = aws_instance.firstInstance.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.LBTargetGroup.arn
  target_id        = aws_instance.secondInstance.id
  port             = 80
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.TerraformALB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.LBTargetGroup.arn
  }
}



# data "template_file" "ec2_user_data" {
#   template = "${"./bootScript.txt"}"
# }

# resource "aws_instance" "testInstance" {
#   ami = "ami-0a8e758f5e873d1c1"
#   instance_type = "t2.micro"
#   associate_public_ip_address = true
#   # user_data = "${data.template_file.ec2_user_data.template}"
#   # iam_instance_profile = "${aws_iam_instance_profile.terraform_profile.name}"
#   # private_ip = "10.0.1.10"
#   # subnet_id = aws_subnet.subnet_az2.id
#     user_data = <<-EOL
#     #!/bin/bash -xe

#     cd /home/ubuntu
#     sudo wget https://github.com/traefik/traefik/releases/download/v1.7.30/traefik_linux-amd64
#     sudo chmod 777 traefik_linux-amd64
#     mkdir configs
#     echo -e '[frontends] \n [frontends.frontend1] \n backend = "backend1" \n  [frontends.frontend1.routes.playgrond] \n  rule = "PathPrefix:/" \n \n[backends] \n  [backends.backend1] \n   [backends.backend1.servers.server1] \n   url = "http://${aws_s3_bucket.terratest-bucket.name}.s3-eu-west-1.amazonaws.com"' > configs/reverse.toml
#     echo -e 'logLevel = "DEBUG" \ndebug=true \ndefaultEntryPoints = ["http"] \n \n[file] \n directory = "/home/ubuntu/configs" \n watch = true \n[entryPoints] \n [entryPoints.http] \n   address = ":80" \n[traefikLog] \n  filePath = "./traefik.log"' > traefik.toml 
#     ./traefik_linux-amd64
#     EOL

#   key_name = "terraform"
#   tags = {
#     Name = "test Instance"
#   }
# }