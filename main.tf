locals {
  period            = "${var.it ? 60 * 60 : (60 * 60 * 24)}"
  is_spot           = "${var.spot_price != ""}"
  need_lb           = "${var.max_size > 1}"
  need_asg          = "${local.need_lb || local.is_spot}"
  min_size          = "${local.need_lb ? var.min_size < 0 ? var.max_size : var.min_size : 1}"
  max_size          = "${local.need_lb ? var.max_size : 1}"
  desired_capacity  = "${local.need_lb ? var.desired_capacity < 0 ? local.min_size : var.desired_capacity : 1}"
  root_block_device = ["${var.root_block_device}"]
  short_name        = "${var.short_name == "" ? substr(var.name, 0, min(24, length(var.name))) : var.short_name}"
  tags              = "${merge(var.tags, map("Name", var.name))}"
}

resource "aws_instance" "this" {
  count                  = "${local.need_lb ? 0 : var.count}"
  ami                    = "${var.ami}"
  subnet_id              = "${element(var.subnets, count.index)}"
  instance_type          = "${var.instance_type}"
  vpc_security_group_ids = ["${var.security_groups}"]
  key_name               = "${var.key_name}"
  tags                   = "${merge(var.tags, map("Name", "${var.count == 1 ? var.name : "${var.name}[${count.index}]"}"))}"
  volume_tags            = "${var.tags}"
  root_block_device      = ["${var.root_block_device}"]
  ebs_block_device       = ["${var.ebs_block_device}"]

  connection {
    type = "ssh"
    user = "ec2-user"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install initscripts nginx",
      "sudo service nginx start",
    ]
  }
}

## Creating Launch Configuration
module "asg" {
  source                    = "git::https://github.com/fabdouglas/terraform-aws-autoscaling?ref=spot_price"
  create_lc                 = "${local.need_asg ? 1 : 0}"
  create_asg                = "${local.need_asg ? 1 : 0}"
  name                      = "${var.name}"
  lc_name                   = "${var.name}"
  asg_name                  = "${var.name}"
  image_id                  = "${var.ami}"
  instance_type             = "${var.instance_type}"
  security_groups           = ["${var.security_groups}"]
  key_name                  = "${var.key_name}"
  tags_as_map               = "${local.tags}"
  vpc_zone_identifier       = ["${var.subnets}"]
  spot_price                = "${var.spot_price}"
  min_size                  = "${local.min_size}"
  max_size                  = "${local.max_size}"
  desired_capacity          = "${local.desired_capacity}"
  load_balancers            = ["${split(",", (local.need_lb && !var.accept_alb) ? module.elb.this_elb_id : "")}"]
  target_group_arns         = ["${module.alb.target_group_arns}"]
  health_check_type         = "${local.need_lb ? "ELB" : "EC2"}"
  root_block_device         = ["${var.root_block_device}"]
  ebs_block_device          = ["${var.ebs_block_device}"]
  health_check_grace_period = "${var.health_check_grace_period}"
  wait_for_capacity_timeout = "${var.wait_for_capacity_timeout}"
  default_cooldown          = "${var.default_cooldown}"

  user_data = <<-EOF
#!/bin/bash
yum -y update
yum -y install initscripts nginx
service nginx start
  EOF
}

resource "aws_autoscaling_policy" "out" {
  count                    = "${local.need_asg ? 1 : 0}"
  name                     = "High CPU"
  scaling_adjustment       = "${var.scale_out_scaling_adjustment}"
  adjustment_type          = "PercentChangeInCapacity"
  min_adjustment_magnitude = 1
  cooldown                 = "${var.scale_out_cooldown}"
  autoscaling_group_name   = "${module.asg.this_autoscaling_group_name}"
}

resource "aws_cloudwatch_metric_alarm" "out" {
  count               = "${local.need_asg ? 1 : 0}"
  alarm_name          = "${var.name}-autoscaling_group-scale_out-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "${var.scale_out_evaluation_periods}"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "${var.scale_out_period}"
  statistic           = "Average"
  threshold           = "${var.scale_out_threshold}"
  alarm_description   = "${jsonencode(merge(local.tags, map("ScaleType", "out")))}"
  alarm_actions       = ["${aws_autoscaling_policy.out.arn}"]

  dimensions {
    AutoScalingGroupName = "${module.asg.this_autoscaling_group_name}"
  }
}

#
resource "aws_autoscaling_policy" "in" {
  count                    = "${local.need_asg ? 1 : 0}"
  name                     = "Low CPU"
  scaling_adjustment       = "${var.scale_in_scaling_adjustment}"
  adjustment_type          = "PercentChangeInCapacity"
  min_adjustment_magnitude = 1
  cooldown                 = "${var.scale_in_cooldown}"
  autoscaling_group_name   = "${module.asg.this_autoscaling_group_name}"
}

resource "aws_cloudwatch_metric_alarm" "in" {
  count               = "${local.need_asg ? 1 : 0}"
  alarm_name          = "${var.name}-autoscaling_group-scale_in-cpu"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "${var.scale_in_evaluation_periods}"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "${var.scale_in_period}"
  statistic           = "Average"
  threshold           = "${var.scale_in_threshold}"
  alarm_description   = "${jsonencode(merge(local.tags, map("ScaleType", "in")))}"
  alarm_actions       = ["${aws_autoscaling_policy.in.arn}"]

  dimensions {
    AutoScalingGroupName = "${module.asg.this_autoscaling_group_name}"
  }
}

module "elb" {
  source                      = "git::https://github.com/fabdouglas/terraform-aws-elb?ref=optional-elb"
  create_elb                  = "${(local.need_lb && !var.accept_alb) ? 1 : 0}"
  name                        = "${local.short_name}"
  subnets                     = ["${var.subnets}"]
  security_groups             = ["${var.security_groups_elb}"]
  tags                        = "${local.tags}"
  internal                    = false
  connection_draining         = true
  connection_draining_timeout = 10

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    },
  ]

  health_check = [
    {
      target              = "HTTP:80/"
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
    },
  ]
}

module "alb" {
  source                    = "git::https://github.com/fabdouglas/terraform-aws-alb?ref=optional-access-logs"
  create_alb                = "${(local.need_lb && var.accept_alb) ? 1 : 0}"
  load_balancer_name        = "${local.short_name}"
  subnets                   = ["${var.subnets}"]
  security_groups           = ["${var.security_groups_elb}"]
  tags                      = "${local.tags}"
  load_balancer_is_internal = false
  vpc_id                    = "${var.vpc_id}"
  http_tcp_listeners        = "${list(map("port", "80", "protocol", "HTTP"))}"
  http_tcp_listeners_count  = "1"
  target_groups             = "${list(map("name", local.short_name, "backend_protocol", "HTTP", "backend_port", "80"))}"
  target_groups_count       = "1"

  target_groups_defaults = {
    cookie_duration                  = "${var.it ? 15 : 86400}"
    deregistration_delay             = "${var.it ? 15 : 300}"
    health_check_healthy_threshold   = "${var.it ? 2 : 3}"
    health_check_interval            = "${var.it ? 5 : 10}"
    health_check_matcher             = "200-299"
    health_check_path                = "/"
    health_check_port                = "traffic-port"
    health_check_timeout             = "${var.it ? 3 : 5}"
    health_check_unhealthy_threshold = "${var.it ? 2 : 3}"
    stickiness_enabled               = true
    target_type                      = "instance"
  }
}
