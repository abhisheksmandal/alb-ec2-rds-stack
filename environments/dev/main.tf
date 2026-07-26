locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Environment = var.environment
  })

  app_ports = [for s in var.services : s.port]

  # Every instance runs every co-located service (e.g. frontend :3000 + backend
  # :4000 on the same 2 boxes), so each instance is attached to every service's
  # target group, on that service's own port.
  service_instance_pairs = flatten([
    for s in var.services : [
      for id in module.compute.instance_ids : {
        key         = "${s.name}-${id}"
        service     = s.name
        port        = s.port
        instance_id = id
      }
    ]
  ])
}

module "networking" {
  source = "../../modules/networking"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  az_count             = var.az_count
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  tags                 = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  name_prefix                 = local.name_prefix
  vpc_id                      = module.networking.vpc_id
  public_subnet_ids           = module.networking.public_subnet_ids
  services                    = var.services
  alb_allowed_cidrs           = var.alb_allowed_cidrs
  enable_deletion_protection  = var.enable_deletion_protection
  enable_https                = var.enable_https
  certificate_arn             = var.certificate_arn
  additional_certificate_arns = var.additional_certificate_arns
  redirect_http_to_https      = var.redirect_http_to_https
  tags                        = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  name_prefix           = local.name_prefix
  vpc_id                = module.networking.vpc_id
  ami_id                = var.ami_id
  instance_type         = var.ec2_instance_type
  instance_count        = var.ec2_instance_count
  root_volume_size      = var.ec2_root_volume_size
  root_volume_type      = var.ec2_root_volume_type
  key_name              = var.ec2_key_name
  enable_ssm            = var.enable_ssm
  ec2_subnet_type       = var.ec2_subnet_type
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  ssh_allowed_cidr      = var.ssh_allowed_cidr
  app_ports             = local.app_ports
  alb_security_group_id = module.alb.alb_security_group_id
  enable_nat_gateway    = var.enable_nat_gateway
  tags                  = local.common_tags
}

# Wired here rather than inside modules/alb or modules/compute — each service's
# target group (owned by the ALB module) needs the compute module's instance
# IDs, so the attachment lives at the composition layer that knows both.
resource "aws_lb_target_group_attachment" "app" {
  for_each = { for p in local.service_instance_pairs : p.key => p }

  target_group_arn = module.alb.target_group_arns[each.value.service]
  target_id        = each.value.instance_id
  port             = each.value.port
}

module "database" {
  source = "../../modules/database"

  name_prefix             = local.name_prefix
  vpc_id                  = module.networking.vpc_id
  private_subnet_ids      = module.networking.private_subnet_ids
  instance_class          = var.db_instance_class
  engine_version          = var.db_engine_version
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  multi_az                = var.db_multi_az
  storage_encrypted       = var.db_storage_encrypted
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  apply_immediately       = var.db_apply_immediately
  db_name                 = var.db_name
  db_username             = var.db_username
  skip_final_snapshot     = var.db_skip_final_snapshot
  ec2_security_group_id   = module.compute.security_group_id
  tags                    = local.common_tags
}
