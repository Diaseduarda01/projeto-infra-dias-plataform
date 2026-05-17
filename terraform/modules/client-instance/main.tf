locals {
  # Plano Bronze:   2 containers React (nginx estático)       → t3.small  + 20 GB
  # Plano Platinum: 9 containers (React + MySQL + NestJS + ...)  → t3.large  + 60 GB
  # Plano Gold:    13 containers (stack completa)              → t3.xlarge + 100 GB
  instance_type = {
    bronze   = "t3.small"
    platinum = "t3.large"
    gold     = "t3.xlarge"
  }[var.tier]

  disk_size = {
    bronze   = 20
    platinum = 60
    gold     = 100
  }[var.tier]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ec2" {
  name = "dias-${var.client_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_backup" {
  name = "dias-${var.client_name}-s3-backup"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
      Resource = [
        "arn:aws:s3:::dias-backup-${var.client_name}",
        "arn:aws:s3:::dias-backup-${var.client_name}/*",
        "arn:aws:s3:::dias-files-${var.client_name}",
        "arn:aws:s3:::dias-files-${var.client_name}/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "dias-${var.client_name}-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_eip" "client" {
  domain = "vpc"
  tags   = { Name = "dias-${var.client_name}-eip", Client = var.client_name }
}

resource "aws_instance" "client" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.instance_type
  key_name               = var.key_pair
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_web_id, var.sg_ssh_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = local.disk_size
    encrypted             = true
    delete_on_termination = true
    tags                  = { Name = "dias-${var.client_name}-root" }
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    client_name = var.client_name
    tier        = var.tier
    domain      = var.domain
    aws_region  = var.aws_region
  })

  tags = {
    Name   = "dias-${var.client_name}"
    Tier   = var.tier
    Client = var.client_name
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip_association" "client" {
  instance_id   = aws_instance.client.id
  allocation_id = aws_eip.client.id
}

resource "aws_cloudwatch_log_group" "client" {
  name              = "/dias/${var.client_name}"
  retention_in_days = 30
  tags              = { Client = var.client_name }
}
