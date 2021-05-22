# variable "aws_region" {
#   description = "AWS region"
#   type        = string
#   default = "eu-west-1"
# }

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




// Get list of all available AZs.
data "aws_availability_zones" "available" {
  state = "available"
}
 

# // VPC to be used
resource "aws_vpc" "public" {
  cidr_block           = var.main_vpc_cidr
  enable_dns_hostnames = true
 tags = {
    Name = "Terraform VPC"
  }
}

// Internet gatway to allow access from the internet to the VPC.
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.public.id
  tags = {
    Name = "Main gateway"
  }
}
// Create subnet one in first AZ.
resource "aws_subnet" "subnet_az1" {
  map_public_ip_on_launch = true
  vpc_id     = aws_vpc.public.id
  cidr_block = var.first_subnet_cidr
  availability_zone= "${data.aws_availability_zones.available.names[0]}"
  tags = {
    Name = "Terraform Subnet az1"
  }
}

// Create subnet one in second AZ.
resource "aws_subnet" "subnet_az2" {
    map_public_ip_on_launch = true
    vpc_id     = aws_vpc.public.id
    cidr_block = var.second_subnet_cidr
    availability_zone= "${data.aws_availability_zones.available.names[1]}"
    tags = {
    Name = "Terraform Subnet az2"
  }
}

// Create route table and route to gateway.
resource "aws_route_table" "route" {
  vpc_id = aws_vpc.public.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Terraform Route table"
  }
}

resource "aws_route_table_association" "routeassoci" {

  subnet_id      = aws_subnet.subnet_az1.id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "routeassoci2" {

  subnet_id      = aws_subnet.subnet_az2.id
  route_table_id = aws_route_table.route.id
}



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

