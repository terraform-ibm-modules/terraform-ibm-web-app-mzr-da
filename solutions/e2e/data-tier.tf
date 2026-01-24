locals {
  data_tier_subnets = flatten([
    for subnet in module.landing_zone.subnet_data : [
      subnet
    ] if strcontains(subnet.name, "${local.workload_vpc}-vsi-data-zone")
  ])

  ## Add kms encryption to the storage volumes
  data_boot_volume_key_list = flatten([
    for keymap in values(module.landing_zone.key_map) : [
      keymap
    ] if strcontains(keymap.name, var.data_boot_volume_encryption_key_suffix)
  ])

  data_boot_volume_key_map = length(local.data_boot_volume_key_list) == 1 ? local.data_boot_volume_key_list[0] : null

  data_block_storage_volumes_list = flatten([
    for vol in var.data_block_storage_volumes : [
      merge(vol, { encryption_key : lookup(local.data_boot_volume_key_map, "crn", null) })
    ]
  ])

  database_ips = [for vsi in module.data_tier_vsi.list : vsi.ipv4_address]
}

data "ibm_is_image" "data_is_image" {
  name = var.data_os_profile
}

# Random password for the database
resource "random_password" "password" {
  length  = 8
  special = false
}

module "data_tier_vsi" {
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.21.2"
  resource_group_id             = local.vpc_data.vpc_data.resource_group
  prefix                        = "${var.prefix}-data-vsi"
  vpc_id                        = local.vpc_data.vpc_id
  subnets                       = local.data_tier_subnets
  image_id                      = data.ibm_is_image.data_is_image.id
  ssh_key_ids                   = [module.landing_zone.ssh_key_data[0].id]
  machine_type                  = var.data_machine_type
  vsi_per_subnet                = var.data_vsi_per_subnet
  kms_encryption_enabled        = var.data_boot_volume_encryption_key_suffix != null ? true : false
  boot_volume_encryption_key    = lookup(local.data_boot_volume_key_map, "crn", null)
  skip_iam_authorization_policy = true
  user_data                     = var.sample_application ? file("${path.module}/templates/data-tier-init-tmplt.tftpl") : null
  enable_floating_ip            = false
  allow_ip_spoofing             = false
  create_security_group         = var.data_security_group != null ? true : false
  security_group                = var.data_security_group
  block_storage_volumes         = local.data_block_storage_volumes_list
  use_legacy_network_interface  = var.use_legacy_network_interface
}

resource "null_resource" "primary_postgresql_install" {
  count = (length(local.database_ips) > 0 && var.sample_application) ? 1 : 0
  connection {
    type         = "ssh"
    user         = "root"
    bastion_host = module.landing_zone.fip_vsi[0].floating_ip
    host         = local.database_ips[0]
    private_key  = var.ssh_private_key
    agent        = false
    timeout      = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "yum update -y",
      "until [ -d /var/lib/pgsql ]; do echo mountpoint does not exist; sleep 5; done",
      "yum install postgresql -y",
      "yum install postgresql-server -y",
      "mkdir /var/lib/pgsql/pgmount/data",
      "chown postgres -R /var/lib/pgsql",
      "PGSETUP_INITDB_OPTIONS='-D /var/lib/pgsql/pgmount/data' /usr/bin/postgresql-setup --initdb",
      "sed -i 's~^Environment=PGDATA=.*~Environment=PGDATA=\\/var/lib/pgsql/pgmount/data/~' /usr/lib/systemd/system/postgresql.service",
      "systemctl enable postgresql",
      "systemctl restart postgresql"
    ]
  }

  provisioner "file" {
    content     = <<EOT
CREATE ROLE replication WITH REPLICATION PASSWORD '${random_password.password.result}' LOGIN;
CREATE DATABASE students_db;
EOT
    destination = "/tmp/psql.commands"
  }

  provisioner "file" {
    content = templatefile("${path.module}/postgresql/primary/postgresql.conf",
      {
        PRIMARY_IP_ADDRESS = local.database_ips[0]
    })
    destination = "/var/lib/pgsql/pgmount/data/postgresql.conf"
  }

  provisioner "file" {
    content = templatefile("${path.module}/postgresql/primary/pg_hba.conf",
      {
        STANDBY_SERVER = length(local.database_ips) > 1 ? local.database_ips[1] : local.database_ips[0]
    })
    destination = "/var/lib/pgsql/pgmount/data/pg_hba.conf"
  }

  provisioner "file" {
    content     = file("${path.module}/postgresql/primary/data.csv")
    destination = "/tmp/data.csv"
  }

  provisioner "file" {
    content = templatefile("${path.module}/postgresql/primary/sql.commands",
      {
        PASSWORD = random_password.password.result
    })
    destination = "/tmp/sql.commands"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo -u postgres psql -f /tmp/psql.commands",
      "systemctl restart postgresql",
      "sudo -u postgres psql -d students_db -f /tmp/sql.commands"
    ]
  }
}

resource "null_resource" "secondary_postgresql_install" {
  count = (length(local.database_ips) > 1 && var.sample_application) ? length(local.database_ips) - 1 : 0
  connection {
    type         = "ssh"
    user         = "root"
    bastion_host = module.landing_zone.fip_vsi[0].floating_ip
    host         = local.database_ips[count.index + 1]
    private_key  = var.ssh_private_key
    agent        = false
    timeout      = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "yum update -y",
      "yum install postgresql-server -y",
      "rm -rf /var/lib/pgsql/data/*",
      "mkdir /var/lib/pgsql/pgmount/data",
      "sudo chown postgres -R /var/lib/pgsql",
      "export PGPASSWORD=${random_password.password.result}",
      "sudo -E -u postgres pg_basebackup -h ${local.database_ips[0]} -D /var/lib/pgsql/pgmount/data -U replication -v -P --wal-method=stream --write-recovery-conf",
      "sudo chown postgres -R /var/lib/pgsql/data",
      "sudo touch /var/lib/pgsql/pgmount/data/standby.signal"
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/postgresql/secondary/postgresql.conf",
      {
        PRIMARY_IP_ADDRESS   = local.database_ips[0]
        SECONDARY_IP_ADDRESS = local.database_ips[count.index + 1]
        PASSWORD             = random_password.password.result
    })
    destination = "/var/lib/pgsql/pgmount/data/postgresql.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's~^Environment=PGDATA=.*~Environment=PGDATA=\\/var/lib/pgsql/pgmount/data/~' /usr/lib/systemd/system/postgresql.service",
      "chmod 700 /var/lib/pgsql/pgmount/data/",
      "systemctl restart postgresql"
    ]
  }

  depends_on = [null_resource.primary_postgresql_install]
}
