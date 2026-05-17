variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "admin_cidr" {
  description = "CIDR permitido para acesso SSH (use SEU_IP/32)"
  type        = string
}

variable "hosted_zone_id" {
  description = "ID da Hosted Zone Route53 para o domínio principal da plataforma"
  type        = string
}

variable "clients" {
  description = "Mapa de clientes a provisionar"
  type = map(object({
    tier        = string # bronze | platinum | gold
    domain      = string # ex: nomecliente.com.br
    key_pair    = string # nome do key pair EC2 existente na AWS
    admin_email = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.clients : contains(["bronze", "platinum", "gold"], v.tier)
    ])
    error_message = "Tier deve ser: bronze, platinum ou gold."
  }
}
