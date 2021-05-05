output "url" {
  value = module.grafana-service.url
}

output "alb_arn_suffix" {
  value = module.lb.arn_suffix
}

output "target_group_name" {
  value = module.grafana-service.target_group_name
}

output "target_group_arn_suffix" {
  value = module.grafana-service.target_group_arn_suffix
}
