# Workshop Automatizar CI/CD AWS

Repositório de infraestrutura como código (Terraform) para workloads AWS, organizado em stacks numeradas e governado por ADRs. O fluxo é: o **Architect Agent** produz um ADR em `docs/`, e o **DevOps Senior Engineer Agent** implementa esse ADR como código Terraform em uma stack dedicada.

## Estrutura do repositório

```
.
├── 01-networking-stack-ai/        # Stack #1: VPC, subnets, NAT, route tables, flow logs
├── docs/                          # ADRs (Architecture Decision Records)
│   └── ADR-0001-networking-stack-vpc-multi-az.md
├── IMPL-ADR-0001-2026-05-23.md    # Relatório de implementação correspondente ao ADR
├── .claude/
│   ├── agents/                    # devops-solution-architect, devops-senior-engineer
│   ├── agent-memory/              # Memória persistente por agente
│   ├── rules/                     # terraform-naming-conventions.md (regra obrigatória)
│   └── skills/terraform-deploy/   # Skill que executa fmt → validate → plan → apply
└── .mcp.json                      # MCP servers: terraform, aws-mcp
```

Cada stack futura segue o padrão `NN-<nome>-stack-ai/` numerada na ordem de provisionamento (networking → compute/data → app).

## Stack tecnológica

- **Terraform** `>= 1.10.0`
- **Provider** `hashicorp/aws ~> 6.0` (resolvido para v6.46.0) — **apenas recursos nativos**, sem módulos comunitários ou de terceiros (decisão do ADR-0001: evitar risco de supply chain)
- **Região padrão**: `us-east-1`
- **Backend**: ainda não há remote backend; quando for criado, a stack `00-remote-backend` deve ser ignorada pela skill `terraform-deploy`

## Convenções obrigatórias

As regras de nomenclatura e estrutura de arquivos são **obrigatórias** e estão em [.claude/rules/terraform-naming-conventions.md](.claude/rules/terraform-naming-conventions.md). Pontos críticos:

- Identificadores Terraform com `_`, valores expostos a humanos com `-`
- Nunca repetir o tipo no nome do recurso (`aws_route_table.public`, não `aws_route_table.public_route_table`)
- `this` para singletons; nomes semânticos quando há múltiplas instâncias
- `count`/`for_each` sempre primeiro no bloco; `tags` sempre por último
- Arquivos seguem `<recurso-pai>.<conceito-filho>.tf` (ex: `vpc.nat-gateway.tf`)
- Variáveis agrupadas em `object({...})` por contexto (`var.vpc`, `var.project`) — **sem `default`**
- Valores ficam em `envs/{dev,staging,production}.tfvars` (nunca `terraform.tfvars` na raiz)
- Outputs no padrão `{name}_{type}_{attribute}`, plural para listas
- `default_tags` configurado no provider para propagar tags a todos os recursos

## Fluxo de trabalho

1. **Planejamento** — invocar o agente `devops-solution-architect` para produzir um ADR em `docs/ADR-NNNN-*.md` antes de qualquer implementação. Trade-offs, opções consideradas, custos estimados e decisão justificada ficam no ADR.
2. **Implementação** — invocar o agente `devops-senior-engineer` passando o ADR. Ele cria a stack `NN-<nome>-stack-ai/` seguindo as convenções, valida via MCP do Terraform Registry, escreve o IaC e gera um `IMPL-ADR-NNNN-YYYY-MM-DD.md` na raiz.
3. **Deploy** — usar a skill `/terraform-deploy [nome-da-stack]` que executa `fmt → validate → plan → apply` por stack, sempre com `-var-file=envs/<env>.tfvars`.

Promoção entre ambientes: **dev → staging → production**, com aprovação humana entre cada etapa. Nunca aplicar diretamente em produção.

## Comandos comuns

```bash
# Validação local de uma stack
cd 01-networking-stack-ai
terraform fmt -recursive
terraform init -backend=false
terraform validate

# Plan/apply de um ambiente
terraform plan  -var-file="envs/dev.tfvars"
terraform apply -var-file="envs/dev.tfvars"
```

## MCP servers disponíveis

- **`terraform`** — consulta o Terraform Registry (providers/módulos/policies). Usar **antes** de gerar HCL para validar versões e capabilities.
- **`aws-mcp`** — proxy autenticado para serviços AWS via SigV4; usar para descoberta de recursos, documentação e validação de comandos AWS.

## Estado atual

Implementada apenas a **stack 01 (networking)**: VPC multi-AZ, 3 subnets públicas, 3 privadas, 1 NAT Gateway compartilhado (otimização de custo conforme decisão do ADR-0001), Flow Logs condicionais para CloudWatch. Downstream stacks (EKS, RDS, ALB) consumirão os outputs (`vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_id`) via `terraform_remote_state` ou SSM Parameter Store quando forem criadas.
