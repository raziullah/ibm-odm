# Keep deterministic names so the pipeline can import/adopt matching dev resources.
resource "aws_db_subnet_group" "odm" {
  name       = "ibm-odm-${var.environment}"
  subnet_ids = local.private_subnet_ids

  depends_on = [terraform_data.network_checks]

  tags = {
    Component   = "ibm-odm"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "ibm-odm-rds-${var.environment}"
  vpc_id      = local.discovered_vpc_id
  description = "RDS PostgreSQL for IBM ODM"

  depends_on = [terraform_data.network_checks]

  tags = {
    Component   = "ibm-odm"
    Environment = var.environment
  }
}

# ROSA workers already have unrestricted outbound traffic in this dev setup.
# Restrict only the RDS ingress source to the confirmed worker security group.
resource "aws_vpc_security_group_ingress_rule" "from_rosa_workers" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = local.rosa_worker_sg_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "IBM ODM ROSA workers to PostgreSQL"

  depends_on = [terraform_data.network_checks]
}

resource "aws_db_parameter_group" "odm" {
  name   = "ibm-odm-${var.environment}"
  family = "postgres${split(".", var.db_engine_version)[0]}"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "immediate"
  }

  tags = {
    Component   = "ibm-odm"
    Environment = var.environment
  }
}

resource "aws_db_instance" "odm" {
  identifier                  = "ibm-odm-${var.environment}"
  engine                      = "postgres"
  engine_version              = var.db_engine_version
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  max_allocated_storage       = var.db_allocated_storage * 2
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "odmdb"
  username                    = "odmadmin"
  manage_master_user_password = true
  port                        = 5432
  publicly_accessible         = false
  multi_az                    = var.db_multi_az
  db_subnet_group_name        = aws_db_subnet_group.odm.name
  vpc_security_group_ids      = [aws_security_group.rds.id]
  parameter_group_name        = aws_db_parameter_group.odm.name
  backup_retention_period     = 7
  copy_tags_to_snapshot       = true
  deletion_protection         = var.db_deletion_protection
  skip_final_snapshot         = false
  final_snapshot_identifier   = "ibm-odm-${var.environment}-final"
  auto_minor_version_upgrade  = false
  apply_immediately           = false

  tags = {
    Component   = "ibm-odm"
    Environment = var.environment
  }
}
