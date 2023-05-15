output "alb_dns_name" {
  value       = aws_lb.terra-ec2.dns_name
  description = "The domain name of the load balancer"
}

output "asg_name" {
  value       = aws_autoscaling_group.terra-ec2.name
  description = "The name of the Auto Scaling Group"
}
