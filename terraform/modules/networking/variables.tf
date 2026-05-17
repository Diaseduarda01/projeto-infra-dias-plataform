variable "project" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "admin_cidr" {
  description = "CIDR com acesso SSH (ex: 177.x.x.x/32)"
  type        = string
}
