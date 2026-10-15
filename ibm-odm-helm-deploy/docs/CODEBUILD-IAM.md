# Terraform-managed CodeBuild IAM

Set `codebuild_project_name` in `infra/environments/dev.tfvars` (example: `ibm-odm-bootstrap-dev`). Terraform creates a dedicated service role, scoped trust policy, inline policy, log group and project. Do not provide `codebuild_role_arn`.

The role can read the configured oc archive object, cluster login secret, shared CodeCommit repository and write its own logs. VPC CodeBuild also needs EC2 network-interface permissions. No broad AdministratorAccess or `secretsmanager:*` is attached.

The ADO AWS service connection needs permissions to create/update IAM roles and policies, including `iam:PassRole` on the generated role. It also needs the pre-existing infrastructure permissions. Terraform cannot bootstrap its own ADO permissions.

If the oc archive uses a customer-managed KMS key, allow `kms:Decrypt` on that key. If CodeCommit is cross-account, configure repository access accordingly. These are not granted automatically.

**Migration:** If the existing CodeBuild project is already Terraform-managed, changing `service_role` updates it to the new role. If the old role was externally created, Terraform will not delete it. Confirm the project's existing name matches `codebuild_project_name` to avoid replacement.
