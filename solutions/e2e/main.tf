##############################################################################
# 3-Tier Web resiliency pattern
##############################################################################

##############################################################################
# Landing zone
##############################################################################

module "landing_zone" {
  source               = "git::https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone.git//patterns/vsi/module?ref=v7.4.7"
  prefix               = var.prefix
  region               = var.region
  ssh_public_key       = var.ssh_key
  override_json_string = templatefile("${path.module}/override.tftpl", { prefix = var.prefix })
}

##############################################################################

##############################################################################
# Secrets Manager
##############################################################################
locals {
  #Check to see if resource group was provisioned in landing zone
  service_rg_in_lz = flatten([
    for rg in module.landing_zone.resource_group_names : [
      rg
    ] if strcontains(rg, "service")
  ])

  sm_region = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region

  sm_rg_id = (var.sm_instance_rg_existing || (!var.sm_instance_rg_existing && var.sm_instance_rg_name != null)) ? module.sm_resource_group[0].resource_group_id : (length(local.service_rg_in_lz) != 0 ?
  module.landing_zone.resource_group_data[local.service_rg_in_lz[0]] : values(module.landing_zone.resource_group_data)[0])

  sm_guid = var.existing_sm_instance_guid == null && var.use_sm ? ibm_resource_instance.secrets_manager[0].guid : var.existing_sm_instance_guid
}

module "sm_resource_group" {
  count = var.sm_instance_rg_existing || (!var.sm_instance_rg_existing && var.sm_instance_rg_name != null) ? 1 : 0

  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.1.6"

  resource_group_name          = !var.sm_instance_rg_existing ? var.sm_instance_rg_name : null
  existing_resource_group_name = var.sm_instance_rg_existing ? var.sm_instance_rg_name : null
}

# Create a new SM instance if not using an existing one
resource "ibm_resource_instance" "secrets_manager" {
  count             = (var.use_sm && var.existing_sm_instance_guid == null) ? 1 : 0
  name              = "${var.prefix}-sm-instance"
  service           = "secrets-manager"
  plan              = var.sm_service_plan
  location          = local.sm_region
  resource_group_id = local.sm_rg_id
  tags              = var.resource_tags
  timeouts {
    create = "20m" # Extending provisioning time to 20 minutes
  }
  provider = ibm.ibm-sm
}

# Configure private cert engine if provisioning a new SM instance
module "private_secret_engine" {
  depends_on                = [ibm_resource_instance.secrets_manager]
  count                     = (var.use_sm && var.existing_sm_instance_guid == null) ? 1 : 0
  source                    = "terraform-ibm-modules/secrets-manager-private-cert-engine/ibm"
  version                   = "1.3.4"
  secrets_manager_guid      = local.sm_guid
  region                    = local.sm_region
  root_ca_name              = var.root_ca_name
  root_ca_common_name       = var.root_ca_common_name
  root_ca_max_ttl           = "8760h"
  intermediate_ca_name      = var.intermediate_ca_name
  certificate_template_name = var.certificate_template_name

  providers = {
    ibm = ibm.ibm-sm
  }
}

# Create a secret group to place the certificate in
module "secrets_manager_group" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.2.2"
  count                    = var.use_sm ? 1 : 0
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-certificates-secret-group"
  secret_group_description = "secret group used for private certificates"
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Create private cert to use for VPN server
module "secrets_manager_private_certificate" {
  depends_on             = [module.private_secret_engine]
  source                 = "terraform-ibm-modules/secrets-manager-private-cert/ibm"
  version                = "1.3.2"
  count                  = var.use_sm ? 1 : 0
  cert_name              = "${var.prefix}-cts-vpn-private-cert"
  cert_description       = "Example private cert"
  cert_template          = var.certificate_template_name
  cert_secrets_group_id  = module.secrets_manager_group[0].secret_group_id
  cert_common_name       = var.cert_common_name
  secrets_manager_guid   = local.sm_guid
  secrets_manager_region = local.sm_region
  providers = {
    ibm = ibm.ibm-sm
  }
}

resource "ibm_iam_authorization_policy" "s2s_lb_to_sm" {
  count = var.use_sm && var.create_s2s_lb_to_sm ? 1 : 0

  source_service_name         = "is"
  source_resource_type        = "load-balancer"
  target_service_name         = "secrets-manager"
  target_resource_instance_id = ibm_resource_instance.secrets_manager[0].guid
  roles                       = ["Writer"]
}

##############################################################################
