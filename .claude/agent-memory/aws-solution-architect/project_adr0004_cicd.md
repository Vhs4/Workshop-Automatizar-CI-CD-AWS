---
name: project_adr0004_cicd
description: ADR-0004 entregue em 2026-05-24 - CI/CD com GitHub Actions OIDC, push model com kubectl set image, nova stack 03-cicd-stack-ai
type: project
---

ADR-0004 (Proposed) salvo em `dvn-workshop-terraform/docs/ADR-0004-cicd-github-actions-oidc.md`.

**Why**: Workshop precisa automatizar deploy dos 2 apps (backend ASP.NET + frontend Next.js) que ja rodam manualmente no cluster EKS dvn-workshop-production. Decisoes-chave alinhadas com humano antes de escrever: push model (sem ArgoCD/Flux), trigger em push para main, image tag = SHA curto do commit. Apresentei essas decisoes como dadas e justifiquei contra Well-Architected; alternativas (GitOps, semver, tag-trigger) foram cobertas apenas em "Opcoes Consideradas".

**How to apply**: 
- Stack `03-cicd-stack-ai` provisiona: OIDC provider GitHub, 2 roles IAM (ci read-only para PR, deploy para push em main), inline policies escopadas (ECR push limitado aos 2 repos por ARN, eks:DescribeCluster apenas no cluster), Access Entry com `AmazonEKSEditPolicy` no namespace `youtube-live`.
- Workflows (`.github/workflows/backend.yml` + `frontend.yml`) NAO sao IaC desta stack - ficam no repo separadamente. 1 workflow por app com paths filter (decisao explicita: clareza > DRY com matrix).
- Pin actions por SHA, nao por tag (supply chain).
- OIDC trust usa **StringEquals** (nao StringLike) no `sub` claim para evitar a falha classica de wildcard.
- `thumbprint_list` omitido no OIDC provider: provider AWS v6.46.0 documenta que para GitHub/GitLab/Google/Auth0 a validacao usa AWS CA library e thumbprint_list e ignorado.
- ECR `imageTagMutability=IMMUTABLE` recomendado mas implementado em stack futura `04-ecr-stack-ai` (repos hoje sao MUTABLE e foram criados fora do IaC).
- Hardening futuro disponivel: validar `job_workflow_ref` claim (feature AWS de fev/2026) - documentado em Open Questions.
- Smoke test: `kubectl rollout status --timeout=3m` + rollback automatico via `kubectl rollout undo` em falha.

Pre-req validado via MCP em 2026-05-24: provider hashicorp/aws ~> 6.0 -> 6.46.0; AmazonEKSEditPolicy tem permissoes de update/patch em deployments (compativel com `kubectl set image`); STS suporta claims GitHub-especificos desde fev/2026.

Stack 03 ainda nao deployada - aguarda devops-senior-engineer implementar com base no ADR.
