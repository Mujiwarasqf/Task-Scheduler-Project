# CI/CD with GitHub Actions (Terraform + AWS OIDC)

This repo includes two workflows:

1) **terraform-plan.yml** (PRs) — runs `terraform fmt/validate/plan` and uploads the plan artifact.
2) **terraform-apply.yml** (main) — runs `terraform plan` + `terraform apply`, then invalidates CloudFront so UI updates go live.

## Required GitHub secrets (Repository → Settings → Secrets and variables → Actions)
- `AWS_ROLE_TO_ASSUME` — IAM role ARN in your AWS account that trusts GitHub OIDC and has permissions for the infra in `infra/`.
- `AWS_REGION` — e.g., `eu-west-2` (optional; defaults to eu-west-2 if not set).

## OIDC IAM Role (AWS side)
Create an IAM role (e.g., `GitHubActionsTerraformRole`) with trust policy for GitHub OIDC. Example principal and conditions:

- Provider: `token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- Condition `StringLike`: `token.actions.githubusercontent.com:sub` should match your repo, e.g.
  `repo:OWNER/REPO:*`

Attach policies (least privilege recommended). For demo, AdministratorAccess is simplest (not for production).

## Remote state (recommended)
To make `apply` reliable from CI, configure Terraform **S3 backend** in `infra/` (bucket + DynamoDB lock table). Without a remote backend, the state is ephemeral in the GitHub runner.