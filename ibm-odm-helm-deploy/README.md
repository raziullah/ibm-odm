# IBM ODM 9.6.0.0-IF003 — ROSA HCP + RDS + GitOps

**Scope: development environment only.** This project bootstraps the existing ROSA HCP development cluster, a private PostgreSQL RDS instance, and Argo CD GitOps content in the shared CodeCommit repository `ibm-operators-odm-dev`.

## Pipeline flow

1. Azure DevOps downloads the IBM ODM production chart `26.0.3` from IBM's public Helm repository. The Azure agent needs Helm and internet access to the IBM chart repository; IBM image entitlement is still needed by the cluster.
2. Terraform initializes its remote S3 state, checks formatting and configuration, and imports deterministic ODM resources that already exist but are not in state. It then plans and applies the dev RDS, RDS security group, and CodeBuild bootstrap project.
3. The publish job extracts the chart, substitutes generated RDS and CodeCommit values, runs `helm lint` and `helm template`, then synchronizes only `ibm-odm/` in CodeCommit. Its `--delete` is scoped to that directory and `git add` stages only that directory. Existing shared repository content outside `ibm-odm/` is preserved.
4. CodeBuild connects to the cluster, creates the namespace, and uses the existing `aws-secrets-manager` ClusterSecretStore to materialize the RDS credential Secret and Argo CD CodeCommit repository Secret. It verifies required Secrets, then applies the AppProject and Application.
5. Argo CD can then read the `ibm-odm/` repository path and deploy the Helm chart after review/sync.

## Configure the dev environment

1. Copy `infra/environments/dev.tfvars.example` to a local file named `ibm-odm-dev.tfvars`, replace every `REPLACE_...` value, then upload it to Azure DevOps as the Secure File `ibm-odm-dev.tfvars`. The pipeline downloads it into `infra/environments/dev.tfvars`; the real file stays out of source control and the project archive.
2. Set `rosa_worker_security_group_tag_key` and `rosa_worker_security_group_tag_value` to identify the confirmed IBM ODM worker-node SG. The example searches for `Name` containing `default-sg`. Terraform discovers its ID within the private-subnet VPC, requires exactly one match, and permits only TCP 5432 from that SG to RDS. Worker outbound already allows the connection, so the pipeline does not add worker egress rules.
3. Provide an existing CodeBuild service role, cluster login secret ARN, `oc` client archive S3 URI, and CodeCommit Git credential secret ARN. The CodeCommit Git secret must be a JSON object with `username` and `password` properties for HTTPS Git credentials.
4. Confirm the existing `aws-secrets-manager` ClusterSecretStore is Ready and its IAM role can read the RDS-managed master secret and CodeCommit Git credential secret. The ECR pull secret must already exist in namespace `ibm-odm`.
5. Select a PostgreSQL engine version supported by this IBM ODM release. Validate actual chart `26.0.3` values and configure the required worker node selector and `workload=ibm:NoSchedule` tolerations for every ODM workload before syncing.
6. Configure the Azure DevOps AWS service connection, remote Terraform state bucket, Secure File authorization, Terraform, Helm, AWS CLI, `jq`, and `rsync` on the agent. Queue `azure-pipelines.yml` manually; the pipeline parameter only permits `dev`.

## Terraform adoption and resource ownership

Before planning, `pipelines/infrastructure.yml` checks AWS for the deterministic ODM subnet group, parameter group, RDS security group, PostgreSQL instance, matching ingress rule, CodeBuild project, and CloudWatch log group. It imports only resources that exist and are missing from Terraform state. Review the generated plan before enabling any unattended run.

The ROSA cluster, worker security group, private subnets, shared CodeCommit repository, ClusterSecretStore, ECR pull secret, and IAM roles are existing dependencies; Terraform discovers or references them and does not manage their lifecycle. Import logic does not adopt unrelated AWS resources.

## Development limits

- The database is named `odmdb`; both ODM components initially share it. No unverified SQL initialization workflow is included.
- RDS master credentials are used through the RDS-managed secret for initial development. A least-privilege application database user should be introduced before production.
- `rds.force_ssl=1` enforces encrypted database transport, but chart/client CA validation still needs to be configured.
- `infra/environments/dev.tfvars` contains environment-specific values and is intentionally excluded from source control and the downloadable project archive.
- `values/stage.yaml` and `values/prod.yaml` are references only; this pipeline cannot deploy those environments.

## References

- [IBM ODM IF003](https://www.ibm.com/support/pages/node/7281448)
- [IBM ODM external database configuration](https://www.ibm.com/docs/en/odm/9.6.0?topic=database-configuring-external)
- [IBM ODM production chart parameters](https://www.ibm.com/docs/en/odm/9.6.0?topic=reference-production-parameters)
- `docs/validation-and-prerequisites.md`
- `docs/security-and-certificates.md`
