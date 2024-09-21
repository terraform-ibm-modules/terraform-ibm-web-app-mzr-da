locals {
  app_tier_subnets = flatten([
    for subnet in module.landing_zone.subnet_data : [
      subnet
    ] if strcontains(subnet.name, "${local.workload_vpc}-vsi-app-zone")
  ])

  ## Add kms encryption to the storage volumes
  app_boot_volume_key_list = flatten([
    for keymap in values(module.landing_zone.key_map) : [
      keymap
    ] if strcontains(keymap.name, var.app_boot_volume_encryption_key_suffix)
  ])

  app_boot_volume_key_map = length(local.app_boot_volume_key_list) == 1 ? local.app_boot_volume_key_list[0] : null

  app_block_storage_volumes_list = flatten([
    for vol in var.app_block_storage_volumes : [
      merge(vol, { encryption_key : lookup(local.app_boot_volume_key_map, "crn", null) })
    ]
  ])
}

data "ibm_is_image" "app_is_image" {
  name = var.app_os_profile
}

module "app_tier_autoscale" {
  source                        = "github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi-autoscale?ref=v1.0.1"
  prefix                        = "${var.prefix}-app-tier"
  resource_group_id             = local.vpc_data.resource_group_id
  zone                          = "${var.region}-1"
  image_id                      = data.ibm_is_image.app_is_image.id
  subnets                       = local.app_tier_subnets
  vpc_id                        = local.vpc_data.id
  placement_group_id            = null
  machine_type                  = var.app_machine_type
  ssh_key_ids                   = [module.landing_zone.ssh_key_data[0].id]
  kms_encryption_enabled        = var.app_boot_volume_encryption_key_suffix != null ? true : false
  boot_volume_encryption_key    = lookup(local.app_boot_volume_key_map, "crn", null)
  skip_iam_authorization_policy = true
  create_security_group         = length(var.app_security_group) >= 1 ? true : false
  security_group                = var.app_security_group
  user_data = !(var.sample_application) ? null : templatefile("${path.module}/templates/app-tier-init-tmplt.tftpl",
    {
      PG_DATABASE_IPS      = join(",", local.database_ips)
      PG_DATABASE_PORT     = 5432
      PG_DATABASE_PASSWORD = random_password.password.result
      PG_DATABASE_USER     = "testuser"
  })
  block_storage_volumes = local.app_block_storage_volumes_list
  instance_count        = var.app_instance_count
  load_balancers        = var.app_load_balancers
  application_port      = var.app_application_port
  group_managers        = var.app_group_managers
}
