output "rds_endpoint" {
  description = "Private RDS DNS endpoint for the ODM chart values."
  value       = aws_db_instance.odm.address
}

output "rds_port" {
  description = "PostgreSQL listener port."
  value       = aws_db_instance.odm.port
}

output "rds_master_secret_arn" {
  description = "RDS-managed master credential secret ARN."
  value       = aws_db_instance.odm.master_user_secret[0].secret_arn
}

output "codebuild_project_name" {
  description = "Project name used by the pipeline to start the bootstrap."
  value       = aws_codebuild_project.bootstrap.name
}

output "codecommit_url" {
  description = "Existing shared CodeCommit HTTPS clone URL."
  value       = data.aws_codecommit_repository.shared.clone_url_http
}

output "discovered_vpc_id" {
  value = local.discovered_vpc_id
}

output "discovered_private_subnet_ids" {
  value = local.private_subnet_ids
}

output "codebuild_security_group_id" {
  value = local.tagged_sg_id
}

output "rosa_worker_security_group_id" {
  description = "ID discovered from the configured worker SG tag filter."
  value       = local.rosa_worker_sg_id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

output "codecommit_git_secret_arn" {
  description = "Secrets Manager ARN used by ESO to create the Argo CD repository Secret."
  value       = var.codecommit_git_secret_arn
}

output "codebuild_role_arn" {
  description = "Dedicated Terraform-managed CodeBuild IAM service role ARN."
  value       = aws_iam_role.codebuild.arn
}
