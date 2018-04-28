output "instance" {
  value = "${join(",",compact(split(",", local.need_asg ? "" : join(",", aws_instance.this.*.id))))}"
}

output "public_ip" {
  value = "${join(",",compact(split(",", local.need_asg ? "" : join(",", aws_instance.this.*.public_ip))))}"
}

output autoscaling_group_id {
  value = "${local.need_asg ? module.asg.this_autoscaling_group_id : ""}"
}

output "autoscaling_group_arn" {
  value = "${local.need_asg ? module.asg.this_autoscaling_group_arn : ""}"
}

output "autoscaling_group_name" {
  value = "${local.need_asg ? module.asg.this_autoscaling_group_name : ""}"
}

output elb_id {
  value = "${local.need_lb ? var.accept_alb ? module.alb.load_balancer_id : module.elb.this_elb_id : ""}"
}

output "target_group_arns" {
  value = "${local.need_lb && var.accept_alb ? join(",",module.alb.target_group_arns) : ""}"
}

output "elb_arn" {
  value = "${local.need_lb ? var.accept_alb ? join(",",module.alb.target_group_arns) : module.elb.this_elb_arn : ""}"
}

output "load_balancer_arn_suffix" {
  value = "${local.need_lb && var.accept_alb ? module.alb.load_balancer_arn_suffix : ""}"
}

output "target_group_arn_suffix" {
  value = "${local.need_lb && var.accept_alb ? join(",",module.alb.target_group_arn_suffix) : ""}"
}

output "elb_name" {
  value = "${local.need_lb ? local.short_name : ""}"
}

output "elb_dns" {
  value = "${local.need_lb ? var.accept_alb ? module.alb.dns_name : module.elb.this_elb_dns_name : ""}"
}
