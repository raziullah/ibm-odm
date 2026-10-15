# Dedicated service role; only this CodeBuild project may assume it.
locals {
  oc_cli_object = trimprefix(var.oc_cli_s3_uri, "s3://")
  oc_cli_bucket = split("/", local.oc_cli_object)[0]
  oc_cli_key    = join("/", slice(split("/", local.oc_cli_object), 1, length(split("/", local.oc_cli_object))))
}

data "aws_iam_policy_document" "codebuild_trust" {
  statement {
    sid     = "CodeBuildService"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:project/${var.codebuild_project_name}"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.codebuild_project_name}-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_trust.json
  tags = {
    Component   = "ibm-odm"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid       = "CloudWatchLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.bootstrap.arn}:*"]
  }
  statement {
    sid       = "ReadOcArchive"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.oc_cli_bucket}/${local.oc_cli_key}"]
  }
  statement {
    sid       = "ReadClusterLogin"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.cluster_credentials_secret_arn]
  }
  statement {
    sid       = "ReadGitSource"
    actions   = ["codecommit:GitPull"]
    resources = [data.aws_codecommit_repository.shared.arn]
  }
  # AWS CodeBuild VPC network interface lifecycle needs these EC2 actions.
  statement {
    sid = "VpcNetworkInterfaces"
    actions = [
      "ec2:CreateNetworkInterface", "ec2:DescribeDhcpOptions", "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }
  statement {
    sid       = "VpcNetworkInterfacePermission"
    actions   = ["ec2:CreateNetworkInterfacePermission"]
    resources = ["arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:network-interface/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.codebuild_project_name}-permissions"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}
