variable "client_name" {
  type = string
}

variable "domain" {
  description = "Domínio do cliente (ex: nomecliente.com.br)"
  type        = string
}

variable "public_ip" {
  description = "IP público (EIP) da instância EC2 do cliente"
  type        = string
}

variable "hosted_zone_id" {
  description = "ID da Hosted Zone Route53 onde o domínio está registrado"
  type        = string
}
