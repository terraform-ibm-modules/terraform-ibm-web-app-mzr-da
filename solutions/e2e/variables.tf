##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "The IBM Cloud platform API key needed to deploy IAM enabled resources."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "IBM Cloud region where the resources will be created."
  type        = string
}

variable "prefix" {
  description = "A unique identifier for resources. Must begin with a lowercase letter and end with a lowerccase letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string
  default     = "lab"

  validation {
    error_message = "Prefix must begin with a lowercase letter and contain only lowercase letters, numbers, and - characters. Prefixes must end with a lowercase letter or number and be 16 or fewer characters."
    condition     = can(regex("^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix)) && length(var.prefix) <= 16
  }
}

variable "ssh_key" {
  description = "Public SSH Key for VSI creation. Must be a valid SSH key that does not already exist in the deployment region."
  type        = string
}

variable "ssh_private_key" {
  description = "Private SSH key (RSA format) that is paired with the public ssh key."
  type        = string
  sensitive   = true
}

############################################################################
# Sample web application
############################################################################
variable "sample_application" {
  description = "Apply the sample web application to the pattern."
  type        = bool
  default     = false
}

############################################################################
# Secret Manager variables
############################################################################
variable "use_sm" {
  type        = bool
  description = "Whether to use Secrets Manager to generate certificates."
  default     = true
}

variable "existing_sm_instance_guid" {
  type        = string
  description = "An existing Secrets Manager GUID. The existing Secret Manager instance must have private certificate engine configured. If not provided an new instance will be provisioned."
  default     = null
}

variable "existing_sm_instance_region" {
  type        = string
  description = "Required if value is passed into `var.existing_sm_instance_guid`."
  default     = null
}

variable "sm_instance_rg_name" {
  type        = string
  description = "Resource group to provison the secrets manager instance.  If no resource group name is defined, it will try to use the service resource group otherwise a random from the landing zone"
  default     = null
}

variable "sm_instance_rg_existing" {
  type        = bool
  description = "Resource group exists in your account already. If set to `true`, you will need to set the variable sm_instance_rg_name"
  default     = false
}

variable "sm_service_plan" {
  type        = string
  description = "The service/pricing plan to use when provisioning a new Secrets Manager instance. Allowed values: `standard` and `trial`."
  default     = "standard"
}

variable "root_ca_name" {
  type        = string
  description = "The name of the Root CA to create for a private_cert secret engine. Only used when `var.existing_sm_instance_guid` is `false`."
  default     = "root-ca"
}

variable "root_ca_common_name" {
  type        = string
  description = "A fully qualified domain name or host domain name for the certificate to be created."
  default     = "example.com"
}

variable "intermediate_ca_name" {
  type        = string
  description = "The name of the Intermediate CA to create for a private_cert secret engine. Only used when `var.existing_sm_instance_guid` is `false`."
  default     = "intermediate-ca"
}

variable "certificate_template_name" {
  type        = string
  description = "The name of the Certificate Template to create for a private_cert secret engine. When `var.existing_sm_instance_guid` is `true`, then it has to be the existing template name that exists in the private cert engine."
  default     = "my-template"
}

variable "cert_common_name" {
  type        = string
  description = "A fully qualified domain name or host domain name for the certificate to be created."
  default     = "test.webapp.com"
}

variable "create_s2s_lb_to_sm" {
  type        = bool
  description = "Create a service-to-service authorization between VPC LB and Secrets Manager."
  default     = true
}

############################################################################
# Web tier variables
############################################################################
variable "web_machine_type" {
  description = "Web tier machine type to use"
  type        = string
  default     = "cx2-2x4"
}

variable "web_os_profile" {
  description = "Web tier os name to use"
  type        = string
  default     = "ibm-centos-stream-9-amd64-5"
}

variable "web_boot_volume_encryption_key_suffix" {
  description = "Web tier boot volume encryption key suffix"
  type        = string
  default     = "vsi-volume-key"
}

variable "web_security_group" {
  description = "The security group surrounding the web tier VSIs"
  type = object({
    name                         = string
    add_ibm_cloud_internal_rules = optional(bool, false)
    rules = list(
      object({
        name      = string
        direction = string
        source    = string
        tcp = optional(
          object({
            port_max = number
            port_min = number
          })
        )
        udp = optional(
          object({
            port_max = number
            port_min = number
          })
        )
        icmp = optional(
          object({
            type = number
            code = number
          })
        )
      })
    )
  })
  default = {
    name : "web-sg",
    rules : [
      {
        direction = "inbound",
        name      = "allow-vpc-inbound",
        source    = "10.0.0.0/8"
      },
      {
        direction = "inbound",
        name      = "allow-ibm-inbound",
        source    = "161.26.0.0/16"
      },
      {
        direction = "outbound",
        name      = "allow-vpc-outbound",
        source    = "10.0.0.0/8"
      },
      {
        direction = "outbound",
        name      = "allow-ibm-outbound",
        source    = "161.26.0.0/16"
      }
    ]
  }
}

variable "web_block_storage_volumes" {
  description = "List describing the block storage volumes that will be attached to each vsi"
  type = list(
    object({
      name              = string
      profile           = string
      capacity          = optional(number)
      iops              = optional(number)
      encryption_key    = optional(string)
      resource_group_id = optional(string)
    })
  )
  default = []
}

variable "web_instance_count" {
  type        = number
  description = "The number of instances to create in the instance group."
  default     = 1
}

variable "web_application_port" {
  type        = number
  description = "The instance group the web tier uses when scaling up instances to supply the port for the Load Balancer pool member."
  default     = 80
}

variable "web_load_balancers" {
  description = "Load balancers to add to VSI"
  type = list(
    object({
      name                    = string
      type                    = string
      listener_port           = number
      listener_protocol       = string
      connection_limit        = number
      idle_connection_timeout = optional(number)
      algorithm               = string
      protocol                = string
      health_delay            = number
      health_retries          = number
      health_timeout          = number
      health_type             = string
      pool_member_port        = string
      profile                 = optional(string)
      dns = optional(
        object({
          instance_crn = string
          zone_id      = string
        })
      )
      security_group = optional(
        object({
          name = string
          rules = list(
            object({
              name      = string
              direction = string
              source    = string
              tcp = optional(
                object({
                  port_max = number
                  port_min = number
                })
              )
              udp = optional(
                object({
                  port_max = number
                  port_min = number
                })
              )
              icmp = optional(
                object({
                  type = number
                  code = number
                })
              )
            })
          )
        })
      )
    })
  )

  default = [{
    name              = "web-lb",
    type              = "public",
    listener_port     = 443,
    listener_protocol = "http",
    connection_limit  = 10,
    protocol          = "http",
    pool_member_port  = 80,
    algorithm         = "round_robin",
    health_delay      = 60,
    health_retries    = 5,
    health_timeout    = 30,
    health_type       = "tcp",
    security_group = {
      name = "web-lb-sg",
      rules = [
        {
          direction = "inbound",
          name      = "allow-all-inbound",
          source    = "0.0.0.0/0",
          tcp = {
            port_max = 443,
            port_min = 443
          }
        },
        {
          direction = "outbound",
          name      = "allow-vpc-outbound",
          source    = "10.0.0.0/8"
        }
      ]
    }
  }]
}

variable "web_group_managers" {
  description = "Instance group manager to add to the instance group"
  type = list(
    object({
      name                 = string
      aggregation_window   = optional(number)
      cooldown             = optional(number)
      enable_manager       = optional(bool)
      manager_type         = string
      max_membership_count = optional(number)
      min_membership_count = optional(number)
      actions = optional(
        list(
          object({
            name                 = string
            cron_spec            = optional(string)
            membership_count     = optional(number)
            max_membership_count = optional(number)
            min_membership_count = optional(number)
            run_at               = optional(string)
          })
        )
      )
      policies = optional(
        list(
          object({
            name         = string
            metric_type  = string
            metric_value = number
            policy_type  = string
          })
        )
      )
    })
  )

  default = [
    {
      name                 = "web"
      aggregation_window   = 120
      cooldown             = 300
      manager_type         = "autoscale"
      enable_manager       = true
      max_membership_count = 4
      min_membership_count = 1
      policies = [{
        name         = "web-policy"
        metric_type  = "cpu"
        metric_value = 70
        policy_type  = "target"
      }]
    }
  ]
}

############################################################################
# Application tier variables
############################################################################
variable "app_machine_type" {
  description = "Application tier machine type to use"
  type        = string
  default     = "cx2-2x4"
}

variable "app_os_profile" {
  description = "Application tier machine type to use"
  type        = string
  default     = "ibm-centos-stream-9-amd64-5"
}

variable "app_boot_volume_encryption_key_suffix" {
  description = "App tier boot volume encryption key suffix"
  type        = string
  default     = "vsi-volume-key"
}

variable "app_security_group" {
  description = "The security group surrounding the application tier VSIs"
  type = object({
    name                         = string
    add_ibm_cloud_internal_rules = optional(bool, false)
    rules = list(
      object({
        name      = string
        direction = string
        source    = string
        tcp = optional(
          object({
            port_max = number
            port_min = number
          })
        )
        udp = optional(
          object({
            port_max = number
            port_min = number
          })
        )
        icmp = optional(
          object({
            type = number
            code = number
          })
        )
      })
    )
  })
  default = {
    name : "app-sg",
    rules : [
      {
        direction = "inbound",
        name      = "allow-vpc-inbound",
        source    = "10.0.0.0/8"
      },
      {
        direction = "inbound",
        name      = "allow-ibm-inbound",
        source    = "161.26.0.0/16"
      },
      {
        direction = "outbound",
        name      = "allow-vpc-outbound",
        source    = "10.0.0.0/8"
      },
      {
        direction = "outbound",
        name      = "allow-ibm-outbound",
        source    = "161.26.0.0/16"
      }
    ]
  }
}

variable "app_block_storage_volumes" {
  description = "List describing the block storage volumes that will be attached to each vsi"
  type = list(
    object({
      name              = string
      profile           = string
      capacity          = optional(number)
      iops              = optional(number)
      encryption_key    = optional(string)
      resource_group_id = optional(string)
    })
  )
  default = []
}

variable "app_instance_count" {
  type        = number
  description = "The number of instances to create in the instance group."
  default     = 1
}

variable "app_application_port" {
  type        = number
  description = "The instance group the application tier uses when scaling up instances to supply the port for the Load Balancer pool member."
  default     = 3000
}

variable "app_load_balancers" {
  description = "Load balancers to add to VSI"
  type = list(
    object({
      name                    = string
      type                    = string
      listener_port           = number
      listener_protocol       = string
      connection_limit        = number
      idle_connection_timeout = optional(number)
      algorithm               = string
      protocol                = string
      health_delay            = number
      health_retries          = number
      health_timeout          = number
      health_type             = string
      pool_member_port        = string
      profile                 = optional(string)
      dns = optional(
        object({
          instance_crn = string
          zone_id      = string
        })
      )
      security_group = optional(
        object({
          name = string
          rules = list(
            object({
              name      = string
              direction = string
              source    = string
              tcp = optional(
                object({
                  port_max = number
                  port_min = number
                })
              )
              udp = optional(
                object({
                  port_max = number
                  port_min = number
                })
              )
              icmp = optional(
                object({
                  type = number
                  code = number
                })
              )
            })
          )
        })
      )
    })
  )

  default = [{
    name              = "app-lb",
    type              = "private",
    listener_port     = 3000,
    listener_protocol = "tcp",
    connection_limit  = 10,
    protocol          = "tcp",
    pool_member_port  = 3000,
    algorithm         = "round_robin",
    health_delay      = 60,
    health_retries    = 5,
    health_timeout    = 30,
    health_type       = "tcp",
    security_group = {
      name = "app-lb-sg",
      rules = [
        {
          direction = "inbound",
          name      = "allow-vpc-inbound",
          source    = "10.0.0.0/8"
        },
        {
          direction = "outbound",
          name      = "allow-vpc-outbound",
          source    = "10.0.0.0/8"
        }
      ]
    }
  }]
}

variable "app_group_managers" {
  description = "Instance group manager to add to the instance group"
  type = list(
    object({
      name                 = string
      aggregation_window   = optional(number)
      cooldown             = optional(number)
      enable_manager       = optional(bool)
      manager_type         = string
      max_membership_count = optional(number)
      min_membership_count = optional(number)
      actions = optional(
        list(
          object({
            name                 = string
            cron_spec            = optional(string)
            membership_count     = optional(number)
            max_membership_count = optional(number)
            min_membership_count = optional(number)
            run_at               = optional(string)
          })
        )
      )
      policies = optional(
        list(
          object({
            name         = string
            metric_type  = string
            metric_value = number
            policy_type  = string
          })
        )
      )
    })
  )

  default = [
    {
      name                 = "app"
      aggregation_window   = 120
      cooldown             = 300
      manager_type         = "autoscale"
      enable_manager       = true
      max_membership_count = 4
      min_membership_count = 1
      policies = [{
        name         = "app-policy"
        metric_type  = "cpu"
        metric_value = 70
        policy_type  = "target"
      }]
    }
  ]
}



############################################################################
# Data tier variables
############################################################################
variable "data_machine_type" {
  description = "Application tier machine type to use"
  type        = string
  default     = "cx2-2x4"
}

variable "data_os_profile" {
  description = "Application tier os profile to use"
  type        = string
  default     = "ibm-centos-stream-9-amd64-5"
}

variable "data_boot_volume_encryption_key_suffix" {
  description = "Data tier boot volume encryption key suffix"
  type        = string
  default     = "vsi-volume-key"
}

variable "data_vsi_per_subnet" {
  description = "Application tier number of vsi's per subnet"
  type        = number
  default     = 1
}

variable "data_security_group" {
  description = "The security group surrounding the data tier VSIs"
  type = object({
    name                         = string
    add_ibm_cloud_internal_rules = optional(bool, false)
    rules = list(
      object({
        name      = string
        direction = string
        source    = string
        tcp = optional(
          object({
            port_max = number
            port_min = number
          })
        )
        udp = optional(
          object({
            port_max = number
            port_min = number
          })
        )
        icmp = optional(
          object({
            type = number
            code = number
          })
        )
      })
    )
  })
  default = {
    name : "data-sg",
    rules : [
      {
        direction = "inbound",
        name      = "allow-vpc-inbound",
        source    = "10.0.0.0/8"
      },
      {
        direction = "inbound",
        name      = "allow-ibm-inbound",
        source    = "161.26.0.0/16"
      },
      {
        direction = "outbound",
        name      = "allow-vpc-outbound",
        source    = "10.0.0.0/8"
      },
      {
        direction = "outbound",
        name      = "allow-ibm-outbound",
        source    = "161.26.0.0/16"
      }
    ]
  }
}

variable "data_block_storage_volumes" {
  description = "The data block storage volume to attach to the data VSIs"
  type = list(
    object({
      name              = string
      profile           = string
      capacity          = optional(number)
      iops              = optional(number)
      encryption_key    = optional(string)
      resource_group_id = optional(string)
    })
  )
  default = [
    {
      "name" : "data",
      "profile" : "general-purpose",
      "capacity" : 50
    }
  ]
}
