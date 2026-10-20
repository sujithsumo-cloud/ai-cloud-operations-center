output "aws_region" {
  description = "AWS region used by this deployment."
  value       = var.aws_region
}

output "web_instance_id" {
  description = "ID of the single web EC2 instance."
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "Public IPv4 address of the web server."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "HTTP URL for the Nginx test page."
  value       = "http://${aws_instance.web.public_ip}"
}

output "vpc_id" {
  description = "ID of the project VPC."
  value       = aws_vpc.main.id
}
