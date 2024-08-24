provider "aws" {
  region = "us-east-1"
}

resource "aws_launch_template" "terraform_instance" {
  image_id        = "ami-04a81a99f5ec58529"
  instance_type   = "t2.micro"
  vpc_security_group_ids  = [aws_security_group.instance.id]
  user_data       = base64encode(<<-EOF
 #!/bin/bash
 echo "Hello, World" > index.html
 nohup busybox httpd -f -p ${var.server_port} &
 EOF
 )
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance407"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

resource "aws_autoscaling_group" "terraform_instance" {
  name = "terraform-asg-terraform_instance"
  launch_template {
    id      = aws_launch_template.terraform_instance.id
    version = "$Latest"
  }
  vpc_zone_identifier  = data.aws_subnets.default.ids
  min_size             = 2
  max_size             = 10
  target_group_arns    = [aws_lb_target_group.terraform_tg.arn]
  tag {
    key                 = "name"
    value               = "terraform-asg-terraform_instance"
    propagate_at_launch = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_instances" "asg_instances" {
  filter {
    name   = "tag:name"
    values = ["terraform-asg-terraform_instance"]
  }
}

output "public_ips" {
  value       = data.aws_instances.asg_instances.public_ips
  description = "Public IP addresses of the instances in the Auto Scaling Group"
}

output "private_ips" {
  value       = data.aws_instances.asg_instances.private_ips
  description = "Private IP addresses of the instances in the Auto Scaling Group"
}

resource "aws_lb" "terraform_lb" {
  name               = "terraform-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_security_group" "lb" {
  name = "terraform-lb-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "terraform_tg" {
  name     = "terraform-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }
}

resource "aws_lb_listener" "terraform_listener" {
  load_balancer_arn = aws_lb.terraform_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform_tg.arn
  }
}

output "load_balancer_dns" {
  value       = aws_lb.terraform_lb.dns_name
  description = "DNS name of the load balancer"
}