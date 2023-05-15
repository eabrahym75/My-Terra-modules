# Refer to the template file - install_nginx.sh
data "template_file" "user_data1" {
  template = "${file("./modules/install-nginx.sh")}"

}

# Create EC2 Instance - Ubuntu 20.04 for nginx
resource "aws_instance" "my-nginx-server2ws" {
  ami                    = "ami-0aa2b7722dc1b5612"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  key_name               = "aws_key"
  vpc_security_group_ids = ["${aws_security_group.my_asg.id}"]
  
  # user_data : render the template
  user_data     = base64encode("${data.template_file.user_data1.rendered}")

  tags = {
    "Name" = "Ubuntu Nginx server"
  }
}

# Create a target group for EC2 Instances
resource "aws_lb_target_group" "asg" {
  name     = var.cluster_name
  port     = 80
  protocol = "HTTP"
  vpc_id      = aws_vpc.my_test_vpc1.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Refer to the template file - install_nginx.sh
data "template_file" "user_data2" {
  template = "${file("./modules/install-apache.sh")}"

}

resource "aws_launch_configuration" "terra-launch-a1e" {
  name            = "terra-launch-a1e"
  image_id        = "ami-0fb653ca2d3203ac1"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.my_asg.id]

  # user_data : render the template
  user_data     = base64encode("${data.template_file.user_data2.rendered}")


  # Required when using a launch configuration with an auto scaling group.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "terra-ec2" {
  launch_configuration = aws_launch_configuration.terra-launch-a1e.name
  vpc_zone_identifier  = aws_lb.terra-ec2.subnets
  target_group_arns    = [aws_lb_target_group.asg.arn]
  health_check_type    = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}



resource "aws_lb" "terra-ec2" {
  name               = var.cluster_name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_asg.id]
  subnets            = [aws_subnet.my_test_vpc1_PublicSubnet.id, aws_subnet.my_test_vpc1_PrivateSubnet]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.terra-ec2.arn

  port              = "80"

  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}



resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# Create a VPC
resource "aws_vpc" "my_test_vpc1" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    name = "dev"
  }
}

# creating a subnet
resource "aws_subnet" "my_test_vpc1_PublicSubnet1" {
  vpc_id                  = aws_vpc.my_test_vpc1.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "Public Subnet 1"
  }
}
# creating a subnet
resource "aws_subnet" "my_test_vpc1_PublicSubnet2" {
  vpc_id                  = aws_vpc.my_test_vpc1.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "Public Subnet 2"
  }
}
# creating a subnet
resource "aws_subnet" "my_test_vpc1_PrivateSubnet" {
  vpc_id                  = aws_vpc.my_test_vpc1.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"

  tags = {
    Name = "Private Subnet"
  }
}

# create internet gateway
resource "aws_internet_gateway" "my_test_vpc1_Internetgateway" {
  vpc_id = aws_vpc.my_test_vpc1.id

  tags = {
    Name = "Gateway"
  }
}
# created a  route table to accept traffic from anywhere on the internet
resource "aws_route_table" "vpc_route" {
  vpc_id = aws_vpc.my_test_vpc1.id

  tags = {
    Name = "public-route"
  }
}

resource "aws_route" "route-inline" {
  route_table_id         = aws_route_table.vpc_route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_test_vpc1_Internetgateway.id

}


resource "aws_security_group" "my_asg" {

  name = "My ASG"

  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow inbound HTTPS requests
  ingress {
    description = "Allow Port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH Traffic
  ingress {
    description = "Allow Port 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}