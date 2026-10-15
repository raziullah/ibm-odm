# Development network and secret flow

## RDS network path

The RDS instance is private and has its own security group. The only database ingress created by this project is TCP 5432 from the worker security group discovered from the configured tag filter. Terraform filters the match to the private-subnet VPC and requires exactly one result. The worker group already has broad outbound access in this dev setup, so Terraform does not change its egress rules.

CodeBuild uses the uniquely tagged existing security group and private subnets. Its network path to AWS APIs, S3, Secrets Manager, CodeCommit, and the cluster API must be available through the existing VPC endpoints, NAT, or routing configuration. This project does not add broad network rules.

## Secret flow

- A cluster login secret is read by CodeBuild and used only for `oc login`.
- The existing `aws-secrets-manager` ClusterSecretStore reads the RDS-managed master credential and creates `odm-db-credentials` in `ibm-odm`.
- The same store reads CodeCommit HTTPS Git credentials and creates `ibm-odm-codecommit` in `openshift-gitops`, labeled `argocd.argoproj.io/secret-type: repository`. Argo CD uses that Secret to authenticate to the shared repository.
- The ECR pull Secret is a pre-existing requirement; bootstrap checks for it and does not replace it.

ExternalSecret manifests contain secret ARNs and property names only, not credential values. CodeBuild validates the generated repository Secret without printing username or password data.

## TLS note

Terraform sets `rds.force_ssl=1`. Configure the ODM chart/client with the correct RDS CA bundle and certificate validation. Verify the selected chart supports the required TLS parameters before sync. Do not treat encrypted transport without server validation as complete certificate validation.
