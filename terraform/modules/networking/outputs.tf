output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "sg_web_id" {
  value = aws_security_group.web.id
}

output "sg_ssh_id" {
  value = aws_security_group.ssh.id
}
