resource "aws_security_group" "main" {
  name        = "${var.component}-${var.env}-sg"
  description = "${var.component}-${var.env}-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = var.sg_subnets_cidr
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.allow_prometheus_cidr
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allow_ssh_cidr
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.component}-${var.env}-sg"
  }
}

resource "aws_lb_target_group" "main" {
  name     = "${var.component}-${var.env}-tg"
  port     = var.app_port
  deregistration_delay = 30
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    interval            = 5
    path                = "/health"
    port                = var.app_port
    protocol            = "HTTP"
    timeout             = 4
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = var.listener_arn
  priority     = var.lb_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = ["${local.dns_name}.robobal.store"]
    }
  }
}

resource "aws_launch_template" "main" {
  name = "${var.component}-${var.env}"

  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }

  image_id = data.aws_ami.ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [ aws_security_group.main.id ]

  tag_specifications {
    resource_type = "instance"
    tags = merge({ Name = "${var.component}-${var.env}", Monitor = "true" }, var.tags)
  }

  user_data              = base64encode(templatefile("${path.module}/userdata.sh", {
    env                  = var.env
    component            = var.component
  }))

#  block_device_mappings {
#    device_name = "/dev/sda1"
#
#    ebs {
#      volume_size = 10
#      encrypted   = "true"
#      kms_key_id  = var.kms_key_id
#    }
# }
}

#Creating AWS Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  vpc_zone_identifier = var.subnets
  target_group_arns  = [ aws_lb_target_group.main.arn ]

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
}

#Creating AWS Auto Scaling Group Dynamic Policy
resource "aws_autoscaling_policy" "asg-cpu-rule" {
  name                      = "CPULoadDetect"
  autoscaling_group_name    = aws_autoscaling_group.main.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 120
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 30.0
  }
}

# Creating an AWS Route 53 DNS record in the specified hosted zone
resource "aws_route53_record" "dns" {
  zone_id = "Z09157091J32F5PJ5K67Y"
  name    =  local.dns_name
  type    = "CNAME"
  ttl     = 30
  records = [var.lb_dns_name]
}



















