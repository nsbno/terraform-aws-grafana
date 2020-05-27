# ----------------------------------------
# VPC
# ----------------------------------------
data "aws_availability_zones" "main" {}
locals {
  public_cidr_blocks = [for k, v in data.aws_availability_zones.main.names :
  cidrsubnet(var.vpc_cidr_block, 4, k)]
  private_cidr_blocks = [for k, v in chunklist(data.aws_availability_zones.main.zone_ids, var.private_subnet_count)[0] :
  cidrsubnet(var.vpc_cidr_block, 4, k + length(data.aws_availability_zones.main.names))]
}

module "vpc" {
  source  = "github.com/nsbno/terraform-aws-vpc?ref=ec7f57f"
  name_prefix          = var.name_prefix
  cidr_block           = var.vpc_cidr_block
  public_subnet_cidrs  = local.public_cidr_blocks
  private_subnet_cidrs = local.private_cidr_blocks
  enable_dns_hostnames = true
  create_nat_gateways  = true
  tags                 = var.tags
}

# ----------------------------------------
# ECS Cluster
# ----------------------------------------
resource "aws_ecs_cluster" "cluster" {
  name = "${var.name_prefix}-ecs-cluster"
}

# ----------------------------------------
# ALB Listener
# ----------------------------------------
module "lb" {
  source  = "github.com/nsbno/terraform-aws-loadbalancer?ref=a8cf4b8"
  name_prefix = var.name_prefix
  type        = "application"
  internal    = false
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids
  tags        = var.tags
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = module.lb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    target_group_arn = module.grafana-service.target_group_arn
    type             = "forward"
  }
}

# ----------------------------------------
# Grafana running on Fargate ECS
# ----------------------------------------

module "grafana-service" {
  source                 = "./modules/grafana-service"
  name_prefix            = var.name_prefix
  vpc_id                 = module.vpc.vpc_id
  alb_arn                = module.lb.arn
  private_subnet_ids     = module.vpc.private_subnet_ids
  parameters_key_arn     = var.parameters_key_arn
  cluster_id             = aws_ecs_cluster.cluster.id
  alb_dns_name           = module.lb.dns_name
  route53_zone           = var.route53_zone
  task_definition_memory = var.task_definition_memory
  task_definition_cpu    = var.task_definition_cpu
  rds_instance_type      = var.rds_instance_type
  rds_instance_storage   = var.rds_instance_storage
  snapshot_identifier    = var.snapshot_identifier
  tags                   = var.tags
  grafana_aws_env_img    = var.grafana_aws_env_img
}

# ----------------------------------------
# Security Group Rules
# ----------------------------------------
resource "aws_security_group_rule" "lb_grafana_ingress_rule" {
  security_group_id        = module.grafana-service.service_sg_id
  description              = "Allow LB to communicate the Fargate ECS service."
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 3000
  to_port                  = 3000
  source_security_group_id = module.lb.security_group_id
}

resource "aws_security_group_rule" "lb_ingress_443" {
  security_group_id = module.lb.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

