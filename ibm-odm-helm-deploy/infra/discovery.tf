# Discover private subnets and the uniquely tagged security group used by CodeBuild.
data "aws_subnets" "rosa_private" {
  dynamic "filter" {
    for_each = var.codebuild_subnet_tags

    content {
      name   = "tag:${filter.key}"
      values = [filter.value]
    }
  }
}

data "aws_subnet" "rosa_private" {
  for_each = toset(data.aws_subnets.rosa_private.ids)
  id       = each.value
}

data "aws_security_groups" "tagged" {
  dynamic "filter" {
    for_each = var.codebuild_security_group_tags

    content {
      name   = "tag:${filter.key}"
      values = [filter.value]
    }
  }
}

data "aws_security_group" "tagged" {
  count = length(data.aws_security_groups.tagged.ids) == 1 ? 1 : 0
  id    = one(data.aws_security_groups.tagged.ids)
}

# Find the worker SG by tag within the same VPC as the discovered private subnets.
data "aws_security_groups" "rosa_workers" {
  filter {
    name   = "tag:${var.rosa_worker_security_group_tag_key}"
    values = [var.rosa_worker_security_group_tag_value]
  }

  filter {
    name   = "vpc-id"
    values = [local.discovered_vpc_id]
  }
}

data "aws_security_group" "rosa_workers" {
  count = length(data.aws_security_groups.rosa_workers.ids) == 1 ? 1 : 0
  id    = one(data.aws_security_groups.rosa_workers.ids)
}

locals {
  private_subnet_ids = sort(data.aws_subnets.rosa_private.ids)
  private_vpc_ids    = distinct([for subnet in data.aws_subnet.rosa_private : subnet.vpc_id])
  private_azs        = distinct([for subnet in data.aws_subnet.rosa_private : subnet.availability_zone])
  discovered_vpc_id  = length(local.private_vpc_ids) == 1 ? one(local.private_vpc_ids) : null
  tagged_sg_id       = length(data.aws_security_groups.tagged.ids) == 1 ? one(data.aws_security_groups.tagged.ids) : null
  rosa_worker_sg_id  = length(data.aws_security_groups.rosa_workers.ids) == 1 ? one(data.aws_security_groups.rosa_workers.ids) : null
}

resource "terraform_data" "network_checks" {
  input = local.private_subnet_ids

  lifecycle {
    precondition {
      condition     = length(local.private_subnet_ids) >= 2 && length(local.private_azs) >= 2
      error_message = "Subnet tags must match at least two subnets in distinct Availability Zones."
    }

    precondition {
      condition     = length(local.private_vpc_ids) == 1
      error_message = "All discovered private subnets must belong to exactly one VPC."
    }

    precondition {
      condition     = length(data.aws_security_groups.tagged.ids) == 1
      error_message = "Security group tags must match exactly one security group."
    }

    precondition {
      condition     = length(data.aws_security_group.tagged) == 1 ? data.aws_security_group.tagged[0].vpc_id == local.discovered_vpc_id : false
      error_message = "The CodeBuild security group must belong to the discovered ROSA VPC."
    }

    precondition {
      condition     = length(data.aws_security_groups.rosa_workers.ids) == 1
      error_message = "Worker SG tag filters must match exactly one security group in the discovered ROSA VPC."
    }

    precondition {
      condition     = length(data.aws_security_group.rosa_workers) == 1 ? data.aws_security_group.rosa_workers[0].vpc_id == local.discovered_vpc_id : false
      error_message = "The discovered worker security group must belong to the discovered ROSA VPC."
    }
  }
}
