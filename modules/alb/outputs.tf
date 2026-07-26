output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.main.arn
}

output "alb_security_group_id" {
  description = "ID of the ALB's security group — attach this as an allowed source on the compute security group."
  value       = aws_security_group.alb.id
}

output "target_group_arns" {
  description = "Map of service name -> target group ARN — register instances against these from the composing root module."
  value       = { for name, tg in aws_lb_target_group.service : name => tg.arn }
}
