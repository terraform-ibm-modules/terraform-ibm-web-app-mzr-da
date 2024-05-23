module "vpc_vsi_multizone" {
  source             = "../../"
  ibmcloud_api_key   = var.ibmcloud_api_key
  region             = var.region
  prefix             = var.prefix
  ssh_key            = var.ssh_key
  ssh_private_key    = var.ssh_private_key
  sample_application = var.sample_application
}
