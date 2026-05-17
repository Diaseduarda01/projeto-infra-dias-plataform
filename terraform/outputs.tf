output "client_public_ips" {
  description = "IPs públicos (Elastic IP) de cada cliente"
  value = {
    for k, v in module.client : k => v.public_ip
  }
}

output "client_instance_ids" {
  description = "IDs das instâncias EC2 de cada cliente"
  value = {
    for k, v in module.client : k => v.instance_id
  }
}

output "ecr_repository_urls" {
  description = "URLs dos repositórios ECR para push das imagens"
  value       = module.ecr.repository_urls
}

output "backup_buckets" {
  description = "Buckets S3 de backup por cliente"
  value = {
    for k, v in module.storage : k => v.bucket_name
  }
}

output "vpc_id" {
  description = "ID da VPC principal"
  value       = module.networking.vpc_id
}

output "certificate_arns" {
  description = "ARNs dos certificados ACM por cliente"
  value = {
    for k, v in module.dns : k => v.certificate_arn
  }
}
