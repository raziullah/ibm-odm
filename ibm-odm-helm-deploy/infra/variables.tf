variable "aws_region" {
  description = "AWS region that contains the ROSA cluster and ODM resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment; this project currently supports dev only."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This project currently supports only the dev environment."
  }
}

variable "codebuild_subnet_tags" {
  description = "Tags that uniquely select the private subnets used by CodeBuild and RDS."
  type        = map(string)
}

variable "codebuild_security_group_tags" {
  description = "Tags that uniquely select the existing security group used by CodeBuild."
  type        = map(string)
}

variable "rosa_worker_security_group_tag_key" {
  description = "Tag key used to discover the existing IBM ODM ROSA worker security group."
  type        = string
  default     = "Name"
}

variable "rosa_worker_security_group_tag_value" {
  description = "Tag value filter for the worker SG; EC2 wildcards allow partial matches."
  type        = string
  default     = "*default-sg*"
}

variable "codecommit_repository_name" {
  description = "Existing shared CodeCommit repository; project content is scoped to ibm-odm/."
  type        = string
  default     = "ibm-operators-odm-dev"
}

variable "codebuild_project_name" {
  description = "CodeBuild project name; Terraform creates its dedicated IAM role and policies."
  type        = string
  default     = "ibm-odm-bootstrap-dev"
  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{2,100}$", var.codebuild_project_name))
    error_message = "Use 2-100 letters, digits, underscores or hyphens."
  }
}

variable "cluster_credentials_secret_arn" {
  description = "Secrets Manager ARN containing api_url, username, and password for oc login."
  type        = string
}

variable "codecommit_git_secret_arn" {
  description = "Secrets Manager ARN containing CodeCommit HTTPS Git credentials as username/password JSON fields."
  type        = string
}

variable "oc_cli_s3_uri" {
  description = "S3 URI for the oc client archive accessible from CodeBuild."
  type        = string
}

variable "db_engine_version" {
  description = "PostgreSQL engine version supported by the selected IBM ODM release."
  type        = string
}

variable "db_instance_class" {
  description = "Small development RDS instance class."
  type        = string
  default     = "db.t4g.medium"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 50
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS; false is suitable only for dev."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Protect the dev database from accidental deletion."
  type        = bool
  default     = false
}
