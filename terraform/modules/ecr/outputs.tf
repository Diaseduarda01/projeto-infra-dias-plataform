output "repository_urls" {
  description = "URLs dos repositórios ECR para uso no docker-compose e CI/CD"
  value = {
    for k, v in aws_ecr_repository.service : k => v.repository_url
  }
}
