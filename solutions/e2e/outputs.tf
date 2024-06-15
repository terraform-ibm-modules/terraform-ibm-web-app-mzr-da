##############################################################################
# Outputs
##############################################################################

output "landing_zone" {
  value       = module.landing_zone
  description = "Landing zone configuration"
}

output "vpc_data" {
  value       = module.landing_zone.vpc_data
  description = "Landing zone vpc data"
}
