locals {
  # Bronze: 7 dias | Platinum: 15 dias | Gold: 30 dias
  retention_days = {
    bronze   = 7
    platinum = 15
    gold     = 30
  }[var.tier]
}

# ── Bucket de backup ──────────────────────────────────────────────────────────
resource "aws_s3_bucket" "backup" {
  bucket        = "dias-backup-${var.client_name}"
  force_destroy = false

  tags = {
    Client  = var.client_name
    Tier    = var.tier
    Purpose = "backup"
  }
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration { days = local.retention_days }

    noncurrent_version_expiration { noncurrent_days = 3 }
  }
}

# ── Bucket de arquivos (apenas Gold — ms-manipulation-of-files) ───────────────
resource "aws_s3_bucket" "files" {
  count         = var.tier == "gold" ? 1 : 0
  bucket        = "dias-files-${var.client_name}"
  force_destroy = false

  tags = {
    Client  = var.client_name
    Tier    = var.tier
    Purpose = "files"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "files" {
  count  = var.tier == "gold" ? 1 : 0
  bucket = aws_s3_bucket.files[0].id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "files" {
  count                   = var.tier == "gold" ? 1 : 0
  bucket                  = aws_s3_bucket.files[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
