output "public_ip" {
  description = "Elastic IP do cliente"
  value       = aws_eip.client.public_ip
}

output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.client.id
}

output "log_group_name" {
  description = "Nome do log group no CloudWatch"
  value       = aws_cloudwatch_log_group.client.name
}
