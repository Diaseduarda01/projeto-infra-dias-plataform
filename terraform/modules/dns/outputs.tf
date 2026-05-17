output "certificate_arn" {
  description = "ARN do certificado ACM (usado pelo nginx para TLS termination)"
  value       = aws_acm_certificate.client.arn
}

output "domain_fqdn" {
  value = aws_route53_record.root.fqdn
}
