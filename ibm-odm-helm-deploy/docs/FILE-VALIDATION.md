# Project file validation

Static checks cover project files only; AWS and ROSA behavior requires a dev deployment.

- YAML syntax is checked for all project YAML files, including Azure Pipelines and the CodeBuild buildspec.
- Shell syntax is checked for each inline pipeline/buildspec script.
- Terraform formatting and validation are pipeline gates (`terraform fmt -check -recursive` and `terraform validate`).
- The publish pipeline downloads IBM ODM chart `26.0.3`, then runs `helm lint` and `helm template` against the downloaded chart.
- No standalone `.sh` or `.py` scripts are required; commands are documented in their Terraform, pipeline, and buildspec files.

Terraform and Helm executables are not available in this editing runtime, so the live Terraform and chart checks were not run here. The pipeline will stop on a failed validation. Verify RDS engine compatibility, IAM, DNS, worker scheduling, ECR entitlement, TLS CA trust, and Argo CD sync in the dev environment.
