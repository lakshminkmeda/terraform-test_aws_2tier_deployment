terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">4.16"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# Create vpc, 2 public subnets in 2 different AZ's, 1 private subnet in each of those AZ
resource "aws_vpc" "vpc_myorg" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "vpc_myorg"
  }
}
resource "aws_subnet" "pubsub01" {
  vpc_id            = aws_vpc.vpc_myorg.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
  tags = {
    Name = "public_subnet-01"
  }
  map_public_ip_on_launch = true
}
resource "aws_subnet" "pubsub02" {
  vpc_id            = aws_vpc.vpc_myorg.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1b"
  tags = {
    Name = "public_subnet_02"
  }
  map_public_ip_on_launch = true
}
resource "aws_subnet" "prvsub01" {
  vpc_id            = aws_vpc.vpc_myorg.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-north-1a"
  tags = {
    Name = "private_subnet_01"
  }
  map_public_ip_on_launch = false
}
resource "aws_subnet" "prvub02" {
  vpc_id            = aws_vpc.vpc_myorg.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-north-1b"
  tags = {
    Name = "private_subnet_02"
  }
  map_public_ip_on_launch = false
}

# Create Internet gateway, route tables for public subnets
resource "aws_internet_gateway" "ig_myorg_vpc" {
  vpc_id = aws_vpc.vpc_myorg.id
  tags = {
    Name = "ig_myorg_vpc"
  }
}
resource "aws_route_table" "rt_public_ig" {
  vpc_id = aws_vpc.vpc_myorg.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig_myorg_vpc.id
  }
  tags = {
    Name = "routetable_public_internetgateway"
  }
}
resource "aws_route_table_association" "rt_assoc1_pubsub01" {
  subnet_id      = aws_subnet.pubsub01.id
  route_table_id = aws_route_table.rt_public_ig.id
}
resource "aws_route_table_association" "rt_assoc1_pubsub02" {
  subnet_id      = aws_subnet.pubsub02.id
  route_table_id = aws_route_table.rt_public_ig.id
}

# Security group for vpc
resource "aws_security_group" "publicsg_vpc" {
  name        = "publicsg_vpc"
  description = "Security group for allowing traffic from VPC"
  vpc_id      = aws_vpc.vpc_myorg.id
  depends_on  = [aws_vpc.vpc_myorg]
  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
  }
  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg_vpc"
  }
}

# Security group for Application Load balancer
resource "aws_security_group" "sg_alb" {
  name        = "sg_alb"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.vpc_myorg.id
  depends_on  = [aws_vpc.vpc_myorg]
  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg_alb"
  }
}

# Create EC2 instance for public subnet 01
resource "aws_instance" "web_server_01" {
  ami                         = "ami-0914547665e6a707c"
  instance_type               = "t3.micro"
  security_groups             = [aws_security_group.publicsg_vpc.id]
  subnet_id                   = aws_subnet.pubsub01.id
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user_data.sh")
}
# Create EC2 instance for public subnet 02
resource "aws_instance" "web_server_02" {
  ami                         = "ami-0914547665e6a707c"
  instance_type               = "t3.micro"
  security_groups             = [aws_security_group.publicsg_vpc.id]
  subnet_id                   = aws_subnet.pubsub02.id
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user_data.sh")
}

# Create Application Load Balancer & target groups
resource "aws_lb" "alb_web" {
  name               = "alb-web"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = [aws_subnet.pubsub01.id, aws_subnet.pubsub02.id]
  tags = {
    Name = "alb"
  }
}
resource "aws_lb_target_group" "vpc_target_grp" {
  name     = "vpc-target-grp"
  vpc_id   = aws_vpc.vpc_myorg.id
  port     = "80"
  protocol = "HTTP"
}
resource "aws_lb_target_group" "alb_target_grp" {
  name       = "alb-target-grp"
  vpc_id     = aws_vpc.vpc_myorg.id
  port       = "80"
  protocol   = "HTTP"
  depends_on = [aws_vpc.vpc_myorg]
  health_check {
    interval            = 60
    path                = "/var/www/html/index.html"
    timeout             = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,202"
  }
}
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb_web.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_grp.arn
  }
}
resource "aws_lb_target_group_attachment" "acq_target01" {
  target_group_arn = aws_lb_target_group.alb_target_grp.arn
  target_id        = aws_instance.web_server_01.id
  port             = "80"
}
resource "aws_lb_target_group_attachment" "acq_target02" {
  target_group_arn = aws_lb_target_group.alb_target_grp.arn
  target_id        = aws_instance.web_server_02.id
  port             = "80"
}
