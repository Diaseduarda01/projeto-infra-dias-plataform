variable "client_name" {
  description = "Identificador único do cliente (slug, sem espaços)"
  type        = string
}

variable "tier" {
  description = "Plano do cliente: bronze | platinum | gold"
  type        = string
}

variable "domain" {
  description = "Domínio do cliente (ex: nomecliente.com.br)"
  type        = string
}

variable "key_pair" {
  description = "Nome do Key Pair EC2 existente na AWS"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "sg_web_id" {
  type = string
}

variable "sg_ssh_id" {
  type = string
}

variable "aws_region" {
  type = string
}
