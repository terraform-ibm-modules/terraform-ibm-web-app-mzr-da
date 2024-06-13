locals {
  workload_vpc = "workload"

  ## VPC data for workload
  vpc_data = flatten([
    for vpc in module.landing_zone.vpc_resource_list : [
      vpc
    ] if strcontains(vpc.name, local.workload_vpc)
  ])[0]

  web_tier_subnets = flatten([
    for subnet in module.landing_zone.subnet_data : [
      subnet
    ] if strcontains(subnet.name, "${local.workload_vpc}-vsi-web-zone")
  ])

  ## Add kms encryption to the storage volumes
  web_boot_volume_key_list = flatten([
    for keymap in values(module.landing_zone.key_map) : [
      keymap
    ] if strcontains(keymap.name, var.web_boot_volume_encryption_key_suffix)
  ])

  web_boot_volume_key_map = length(local.web_boot_volume_key_list) == 1 ? local.web_boot_volume_key_list[0] : null

  web_block_storage_volumes_list = flatten([
    for vol in var.web_block_storage_volumes : [
      merge(vol, { encryption_key : lookup(local.web_boot_volume_key_map, "crn", null) })
    ]
  ])
}

data "ibm_is_image" "web_is_image" {
  name = var.web_os_profile
}

module "web_tier_autoscale" {
  depends_on                    = [ibm_iam_authorization_policy.s2s_lb_to_sm]
  source                        = "github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi-autoscale?ref=v1.0.0"
  prefix                        = "${var.prefix}-web-tier"
  resource_group_id             = local.vpc_data.resource_group_id
  zone                          = "${var.region}-1"
  image_id                      = data.ibm_is_image.web_is_image.id
  subnets                       = local.web_tier_subnets
  vpc_id                        = local.vpc_data.id
  placement_group_id            = null
  machine_type                  = var.web_machine_type
  ssh_key_ids                   = [module.landing_zone.ssh_key_data[0].id]
  kms_encryption_enabled        = var.web_boot_volume_encryption_key_suffix != null ? true : false
  boot_volume_encryption_key    = lookup(local.web_boot_volume_key_map, "crn", null)
  skip_iam_authorization_policy = true
  create_security_group         = length(var.web_security_group) >= 1 ? true : false
  security_group                = var.web_security_group
  user_data = !(var.sample_application) ? null : templatefile("${path.module}/templates/web-tier-init-tmplt.tftpl",
    {
      load_balancer = module.app_tier_autoscale.lbs_list[0].hostname
  })
  block_storage_volumes = local.web_block_storage_volumes_list
  instance_count        = var.web_instance_count
  load_balancers = flatten([for lb in var.web_load_balancers :
    [merge(lb, { certificate_instance = (var.use_sm ? module.secrets_manager_private_certificate[0].secret_crn : null), listener_protocol = (var.use_sm ? "https" : "http") })]
  ])
  application_port = var.web_application_port
  group_managers   = var.web_group_managers
}
