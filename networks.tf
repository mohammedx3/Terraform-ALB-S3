// Get list of all available AZs in the region.
data "aws_availability_zones" "available" {
  state = "available"
}
 

// VPC to be used
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

// Add the subnets to the route table so it can be accessed publicly.
resource "aws_route_table_association" "routeassoci" {
  subnet_id      = aws_subnet.subnet_az1.id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "routeassoci2" {
  subnet_id      = aws_subnet.subnet_az2.id
  route_table_id = aws_route_table.route.id
}