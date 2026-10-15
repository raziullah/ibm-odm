# Development validation and prerequisites

## Existing AWS and cluster dependencies

- AWS account and region match the Azure DevOps AWS service connection.
- S3 Terraform backend bucket exists and allows state locking/encryption policy required by the organization.
- Existing ROSA private subnets are identified by `codebuild_subnet_tags`; at least two subnets in separate Availability Zones must match.
- `codebuild_security_group_tags` identify exactly one security group in that VPC for CodeBuild network attachment.
- `rosa_worker_security_group_tag_key` and `rosa_worker_security_group_tag_value` identify the confirmed IBM ODM worker-node security group in the same VPC; the example uses the `Name` tag with `*default-sg*`.
- CodeBuild service role can use VPC networking, read cluster credentials and the CodeCommit repository, and write CloudWatch logs.
- `aws-secrets-manager` ClusterSecretStore is Ready. Its backing IAM permissions allow reading RDS and CodeCommit credential secrets.
- The `ibm-odm` namespace's `ecr-pull-secret` already exists.
- CodeCommit HTTPS credentials are stored in Secrets Manager JSON properties `username` and `password`.
- The cluster can reach RDS privately and Argo CD is installed in `openshift-gitops`.

## Before applying

1. Review the Terraform import list and `terraform plan` output. The first run imports deterministic ODM resources with matching names if they already exist and are absent from the backend state.
2. Verify `dev.tfvars` placeholders and the IBM-supported PostgreSQL version.
3. Confirm the RDS SG ingress rule is TCP 5432 from only the worker SG discovered by tag. The worker SG's existing outbound policy already permits this dev connection; no new egress rule is managed.
4. Ensure the chart download in the publish job succeeds from the Azure agent's internet connection.
5. Run Helm lint and template checks. Validate chart schema, node selectors, tolerations, image tags, persistence, and database settings against the exact IBM chart archive.
6. Verify only `ibm-odm/` changes in the CodeCommit commit. The publisher synchronizes/deletes only beneath that path and stages only that path.

## Bootstrap success checks

The CodeBuild buildspec stops on any failed command and emits a success or failure message. It verifies the AWS account and `oc` client, cluster login, required ODM chart, RDS ExternalSecret readiness, existing ECR pull Secret, and the ESO-created Argo CD CodeCommit repository Secret. It does not print credential values.

After the build succeeds, inspect the Argo CD Application in `openshift-gitops`. Review its diff and sync manually in dev. Confirm pods can reach PostgreSQL and pull their entitled images.
