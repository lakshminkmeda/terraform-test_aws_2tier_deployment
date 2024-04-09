terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">4.16"
    }
  }
}

provider "aws" {
  shared_credentials_files = "~/.aws/credentials"
  region = "eu-north-1"
}

# Create vpc, 2 public subnets in 2 different AZ's, 1 private subnet in each of those AZ
resource "aws_vpc" "a_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = a_vpc
  }
}
resource "aws_subnet" "pubsub01" {
  vpc_id = aws_vpc.a_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
  tags = {
    Name = "public_subnet-01"
  }
}
resource "aws_subnet" "pubsub02" {
  vpc_id = aws_vpc.a_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-north-1b"
  tags = {
    Name = "public_subnet_02"
  }
}
resource "aws_subnet" "prvsub01" {
  vpc_id = aws_vpc.a_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-north-1a"
  tags = {
    Name = "private_subnet_01"
  }
  map_public_ip_on_launch = false
}
resource "aws_subnet" "prvub02" {
  vpc_id = aws_vpc.a_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "eu-north-1b"
  tags = {
    Name = "private_subnet_02"
  }
  map_public_ip_on_launch = false
}

# Create Internet gateway, route tables for public subnets
resource "aws_internet_gateway" "ig_vpc" {
  vpc_id = aws_vpc.a_vpc.id
  tags = {
    Name = "ig_vpc"
  }
}
resource "aws_route_table" "rt_public_ig" {
  vpc_id = aws_vpc.a_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig_pc.id
  }
  tags = {
    Name = "routetable_public_internetgateway"
  }
}
resource "aws_route_table_association" "rt_assoc1_pubsub01" {
  subnet_id = aws_subnet.pubsub01.id
  route_table_id = aws_route_table.rt_public_ig
}
resource "aws_route_table_association" "rt_assoc1_pubsub02" {
  subnet_id = aws_subnet.pubsub02.id
  route_table_id = aws_route_table.rt_public_ig
}

# Security group for vpc
resource "aws_security_group" "publicsg_vpc" {
  name = "publicsg_vpc"
  description = "Security group for allowing traffic from VPC"
  vpc_id = aws_vpc.a_vpc.id
  depends_on = [ aws_vpc.a_vpc ]
  ingress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
  }
  ingress {
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg_vpc"
  }
}

# Security group for Application Load balancer
resource "aws_security_group" "sg_alb" {
  name = "sg_alb"
  description = "Security group for Application Load Balancer"
  vpc_id = aws_vpc.a_vpc.id
  depends_on = [ aws_vpc.a_vpc ]
  ingress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg_alb"
  }
}

# Create EC2 instance for public subnet 01
resource "aws_instance" "web_server_01" {
  ami = "ami-0914547665e6a707c"
  instance_type = "t3.micro"
  security_groups = [aws_security_group.publicsg_vpc.id]
  subnet_id = aws_subnet.pubsub01.id

  user_data = <<-EOF
    #¡/bin/bash
    yum update -y
    tum install httpd -y
    systemctl start
    systemctl enable
    echo '<h1>Apache Web Test on Server 01</h1>' > /use/share/nginx/html/index.html
    EOF
}
# Create EC2 instance for public subnet 02
resource "aws_instance" "web_server_02" {
  ami = "ami-0914547665e6a707c"
  instance_type = "t3.micro"
  security_groups = [aws_security_group.publicsg_vpc.id]
  subnet_id = aws_subnet.pubsub02.id

  user_data = <<-EOF
    #¡/bin/bash
    yum update -y
    tum install httpd -y
    systemctl start
    systemctl enable
    echo '<h1>Apache Web Test on Server 02</h1>' > /use/share/nginx/html/index.html
    EOF
}

