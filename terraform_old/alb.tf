resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB-sg"
  }
}

resource "aws_lb" "alb" {
  name                             = "tf-sample-alb"
  load_balancer_type               = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets                          = aws_subnet.publics[*].id

  tags = {
    Name = "tf-sample-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.backend.arn
  }

  lifecycle {
    ignore_changes = [
      default_action,
    ]
  }
}
