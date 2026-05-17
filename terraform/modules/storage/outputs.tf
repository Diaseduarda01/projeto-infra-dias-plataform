output "bucket_name" {
  description = "Bucket S3 de backup do cliente"
  value       = aws_s3_bucket.backup.bucket
}

output "files_bucket_name" {
  description = "Bucket S3 de arquivos (apenas Gold)"
  value       = var.tier == "gold" ? aws_s3_bucket.files[0].bucket : null
}
