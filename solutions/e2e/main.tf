module "vpc_vsi_multizone" {
  source                                 = "../../"
  ibmcloud_api_key                       = var.ibmcloud_api_key
  region                                 = var.region
  prefix                                 = var.prefix
  resource_tags                          = var.resource_tags
  ssh_key                                = var.ssh_key
  ssh_private_key                        = var.ssh_private_key
  sample_application                     = var.sample_application
  use_sm                                 = var.use_sm
  existing_sm_instance_guid              = var.existing_sm_instance_guid
  existing_sm_instance_region            = var.existing_sm_instance_region
  sm_instance_rg_name                    = var.sm_instance_rg_name
  sm_instance_rg_existing                = var.sm_instance_rg_existing
  sm_service_plan                        = var.sm_service_plan
  root_ca_name                           = var.root_ca_name
  root_ca_common_name                    = var.root_ca_common_name
  intermediate_ca_name                   = var.intermediate_ca_name
  certificate_template_name              = var.certificate_template_name
  cert_common_name                       = var.cert_common_name
  create_s2s_lb_to_sm                    = var.create_s2s_lb_to_sm
  web_machine_type                       = var.web_machine_type
  web_os_profile                         = var.web_os_profile
  web_boot_volume_encryption_key_suffix  = var.web_boot_volume_encryption_key_suffix
  web_security_group                     = var.web_security_group
  web_block_storage_volumes              = var.web_block_storage_volumes
  web_instance_count                     = var.web_instance_count
  web_application_port                   = var.web_application_port
  web_load_balancers                     = var.web_load_balancers
  web_group_managers                     = var.web_group_managers
  app_machine_type                       = var.app_machine_type
  app_os_profile                         = var.app_os_profile
  app_boot_volume_encryption_key_suffix  = var.app_boot_volume_encryption_key_suffix
  app_security_group                     = var.app_security_group
  app_block_storage_volumes              = var.app_block_storage_volumes
  app_instance_count                     = var.app_instance_count
  app_application_port                   = var.app_application_port
  app_load_balancers                     = var.app_load_balancers
  app_group_managers                     = var.app_group_managers
  data_machine_type                      = var.data_machine_type
  data_os_profile                        = var.data_os_profile
  data_boot_volume_encryption_key_suffix = var.data_boot_volume_encryption_key_suffix
  data_vsi_per_subnet                    = var.data_vsi_per_subnet
  data_security_group                    = var.data_security_group
  data_block_storage_volumes             = var.data_block_storage_volumes
}
