variable "key_name" {}
variable instance_type {}
variable "name" {}

variable "it" {
  default = true
}

variable "accept_alb" {
  default = true
}

variable "short_name" {
  default = ""
}

variable "tags" {
  default = {}
}

variable "vpc_id" {
  default = ""
}

variable count {
  default = 1
}

variable ami {}

variable subnets {
  type = "list"
}

variable security_groups {
  type = "list"
}

variable security_groups_elb {
  default = []
}

variable spot_price {
  default = ""
}

variable min_size {
  default = -1
}

variable max_size {
  default = 0
}

variable scale_out_cooldown {
  default = 300
}

variable scale_in_cooldown {
  default = 300
}

variable scale_out_period {
  default = 60
}

variable scale_in_period {
  default = 60
}

variable scale_out_threshold {
  default = 75
}

variable scale_in_threshold {
  default = 20
}

variable scale_in_evaluation_periods {
  default = 2
}

variable scale_out_evaluation_periods {
  default = 2
}

variable scale_in_scaling_adjustment {
  default = -20
}

variable scale_out_scaling_adjustment {
  default = 20
}

variable desired_capacity {
  default = -1
}

variable ebs_block_device {
  default = []
}

variable root_block_device {
  default = [{
    volume_size           = "8"
    volume_type           = "gp2"
    delete_on_termination = true
  }]
}

variable "health_check_grace_period" {
  description = "Time (in seconds) after instance comes into service before checking health"
  default     = 120
}

variable "wait_for_capacity_timeout" {
  description = "A maximum duration that Terraform should wait for ASG instances to be healthy before timing out. (See also Waiting for Capacity below.) Setting this to '0' causes Terraform to skip all Capacity Waiting behavior."
  default     = "3m"
}

variable "default_cooldown" {
  description = "The amount of time, in seconds, after a scaling activity completes before another scaling activity can start"
  default     = 60
}
