# Data Resources 

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id 
} 





# Step-1: Create the Launch Configuration for the Auto Scaling Group

resource "aws_launch_configuration" "dev" {
  image_id = var.image_id
  instance_type = var.instance_type
  security_groups = [aws_security_group.instance.id]
 
   user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}


# Step-2: "Create the Auto Scaling Group"


resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.dev.name 
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
   key =  "Name"
   value = "terraform-asg-example"
   propagate_at_launch = true 
  }
}

resource "aws_security_group" "instance" {
 name = var.instance_security_group_name

 ingress {
  from_port = var.server_port
  to_port = var.server_port
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
}


resource "aws_lb" "dev" {
 name = var.alb_name
 load_balancer_type = "application"
 subnets = data.aws_subnet_ids.default.ids
 security_groups = [aws_security_group.alb.id]
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.dev.arn
  port = 80
  protocol = "HTTP"

  default_action {
   type = "fixed-response"
   
   fixed_response {
    content_type = "text/plain"
    message_body = "404: Page not Found"
    status_code = 404
   }
  }
}


resource "aws_lb_target_group" "asg" {

  name = var.alb_name
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  health_check {
    path = "/" 
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}


resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100
   
  condition {
   path_pattern{
    values = ["*"] 
   }
  }
  action {
   type = "forward"
   target_group_arn = aws_lb_target_group.asg.arn
 }
}

resource "aws_security_group" "alb" {
  name = var.alb_security_group_name
  
  ingress {
   from_port = 80
   to_port = 80 
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
  }
}


