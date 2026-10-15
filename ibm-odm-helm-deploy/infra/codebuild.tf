# Reuse the shared ODM/operations repository without managing its lifecycle.
data "aws_codecommit_repository" "shared" {
  repository_name = var.codecommit_repository_name
}

resource "aws_cloudwatch_log_group" "bootstrap" {
  name              = "/aws/codebuild/${var.codebuild_project_name}"
  retention_in_days = 30
}

resource "aws_codebuild_project" "bootstrap" {
  name          = var.codebuild_project_name
  description   = "Create ODM namespace, ESO credentials and Argo CD Helm Application"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 45

  artifacts {
    type = "NO_ARTIFACTS"
  }

  source {
    type            = "CODECOMMIT"
    location        = data.aws_codecommit_repository.shared.clone_url_http
    git_clone_depth = 1
    buildspec       = "ibm-odm/bootstrap/buildspec.yml"
  }

  source_version = "main"

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "DEPLOY_ENV"
      value = var.environment
    }
    environment_variable {
      name  = "OC_S3_URI"
      value = var.oc_cli_s3_uri
    }
    environment_variable {
      name  = "CLUSTER_CREDENTIALS_SECRET"
      value = var.cluster_credentials_secret_arn
    }
    environment_variable {
      name  = "EXPECTED_AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
  }

  vpc_config {
    vpc_id             = local.discovered_vpc_id
    subnets            = local.private_subnet_ids
    security_group_ids = [local.tagged_sg_id]
  }

  depends_on = [terraform_data.network_checks, aws_iam_role_policy.codebuild]

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.bootstrap.name
    }
  }

  tags = {
    Component   = "ibm-odm"
    Environment = var.environment
  }
}
