---
name: project-cicd-stack
description: ADR-0004 CI/CD stack — GitHub Actions OIDC, IAM roles, EKS access entry. Applied 2026-05-24.
metadata:
  type: project
---

Stack `03-cicd-stack-ai` deployed 2026-05-24. State at `cicd/terraform.tfstate` in S3 bucket `dvn-workshop-production-terraform-state-407295215751`.

**Why:** Replace manual ECR push + kubectl workflow with automated GitHub Actions OIDC-based CI/CD. Zero long-lived AWS credentials in GitHub.

**Key resources created:**
- OIDC Provider: `arn:aws:iam::407295215751:oidc-provider/token.actions.githubusercontent.com` (no thumbprint, prevent_destroy=true)
- CI Role: `arn:aws:iam::407295215751:role/github-actions-ci` (pull_request sub claim, no AWS permissions)
- Deploy Role: `arn:aws:iam::407295215751:role/github-actions-deploy` (main branch sub claim, ECR push + EKS DescribeCluster + AmazonEKSEditPolicy namespace=youtube-live)
- EKS Access Entry + AmazonEKSEditPolicy scoped to namespace `youtube-live`

**GitHub variables PENDING** (gh not authenticated at deploy time):
```
AWS_DEPLOY_ROLE_ARN = arn:aws:iam::407295215751:role/github-actions-deploy
AWS_CI_ROLE_ARN     = arn:aws:iam::407295215751:role/github-actions-ci
AWS_ACCOUNT_ID      = 407295215751
```
Human must run `gh auth login` then set these as **variables** (not secrets — ARNs are not sensitive).

**Workflows:** `.github/workflows/backend.yml` and `.github/workflows/frontend.yml`. Both:
- paths-filtered (backend: `dvn-workshop-apps/backend/**` + `k8s/youtubeliveapp/**`)
- validate job: docker buildx build --platform=linux/arm64 --no-push (all events)
- deploy job: only on push to main — OIDC assume deploy role, ECR login, build+push, kubectl set image, rollout status, auto-rollback on failure

**How to apply:** Not yet committed/pushed — human reviews and does `git add && git commit && git push`.

**Related:** [[project-eks-stack]] (remote state source for cluster ARN/name), [[project-remote-backend]] (S3 state bucket)
