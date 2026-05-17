module "networking" {
  source = "./modules/networking"

  project    = "dias-platform"
  vpc_cidr   = "10.0.0.0/16"
  admin_cidr = var.admin_cidr
}

module "ecr" {
  source = "./modules/ecr"

  services = [
    "ms-chatbot",
    "ms-notificacao",
    "ms-manipulation-of-files",
    "ms-client-scheduling",
    "ms-financeiro",
    "ms-rabbitmq",
    "ms-observabilidade",
    "frontend-sistema",
    "frontend-site",
    "frontend-hub",
  ]
}

module "client" {
  for_each = var.clients
  source   = "./modules/client-instance"

  client_name = each.key
  tier        = each.value.tier
  domain      = each.value.domain
  key_pair    = each.value.key_pair

  vpc_id    = module.networking.vpc_id
  subnet_id = module.networking.public_subnet_ids[0]
  sg_web_id = module.networking.sg_web_id
  sg_ssh_id = module.networking.sg_ssh_id

  aws_region = var.aws_region

  depends_on = [module.networking]
}

module "dns" {
  for_each = var.clients
  source   = "./modules/dns"

  client_name    = each.key
  domain         = each.value.domain
  public_ip      = module.client[each.key].public_ip
  hosted_zone_id = var.hosted_zone_id

  depends_on = [module.client]
}

module "storage" {
  for_each = var.clients
  source   = "./modules/storage"

  client_name = each.key
  tier        = each.value.tier
}
