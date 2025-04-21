output "db_instance_id" {
  description = "The ID of the RDS instance"
  value       = aws_db_instance.main.id
}

output "db_instance_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_endpoint" {
  description = "The connection endpoint of the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_subnet_group_id" {
  description = "The ID of the DB subnet group"
  value       = aws_db_subnet_group.main.id
}

output "db_parameter_group_id" {
  description = "The ID of the DB parameter group"
  value       = aws_db_parameter_group.main.id
}

output "db_name" {
  description = "The name of the database"
  value       = var.db_name
}

output "db_username" {
  description = "The username for the database"
  value       = var.db_username
}

output "db_port" {
  description = "The port of the database"
  value       = var.db_port
}

output "kms_key_id" {
  description = "The ID of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds.id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds.arn
}

output "db_instance_resource_id" {
  description = "The RDS Resource ID of this instance"
  value       = aws_db_instance.main.resource_id
}

output "db_instance_status" {
  description = "The status of the RDS instance"
  value       = aws_db_instance.main.status
}

output "db_instance_domain" {
  description = "The ID of the Directory Service Active Directory domain the instance is joined to"
  value       = aws_db_instance.main.domain
}

output "db_instance_hosted_zone_id" {
  description = "The canonical hosted zone ID of the DB instance (to be used in a Route 53 Alias record)"
  value       = aws_db_instance.main.hosted_zone_id
}

output "db_instance_multi_az" {
  description = "If the RDS instance is multi-AZ"
  value       = aws_db_instance.main.multi_az
}

output "db_instance_availability_zone" {
  description = "The availability zone of the RDS instance"
  value       = aws_db_instance.main.availability_zone
}

output "db_instance_backup_retention_period" {
  description = "The backup retention period"
  value       = aws_db_instance.main.backup_retention_period
}

output "db_instance_backup_window" {
  description = "The backup window"
  value       = aws_db_instance.main.backup_window
}

output "db_instance_maintenance_window" {
  description = "The maintenance window"
  value       = aws_db_instance.main.maintenance_window
}

output "db_instance_latest_restorable_time" {
  description = "The latest time the database can be restored to"
  value       = aws_db_instance.main.latest_restorable_time
}
