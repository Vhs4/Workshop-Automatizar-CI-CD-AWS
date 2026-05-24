---
name: ecr-push
description: Faz o build de uma ou mais imagens Docker e o push delas para o Amazon ECR. Recebe como argumento uma ou mais URIs de imagem ECR completas (formato `<account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>`), faz login no registry, build em `linux/amd64`, tag, push e (se necessário) cria o repositório no ECR. Use esta skill sempre que o usuário pedir para "fazer push pro ECR", "publicar a imagem", "subir a imagem", "build e push", "deploy de imagem Docker" ou variantes — mesmo que não mencione explicitamente "ecr-push". Se o usuário passar várias URIs, processa todas em sequência. Se nenhuma URI for passada, pergunte antes de prosseguir.
---

## O que esta skill faz

Para cada URI ECR informada:

1. **Valida pré-requisitos** (`docker`, `aws` CLI, credenciais AWS).
2. **Parseia a URI** em `account_id`, `region`, `repository`, `tag`.
3. **Garante o login** no registry ECR daquele `account_id`/`region` (faz uma vez por par único).
4. **Garante que o repositório existe** — se não existir, pergunta ao usuário se deve criar (com `image_tag_mutability=MUTABLE` e scan-on-push habilitado por default).
5. **Build da imagem** para `linux/amd64`, partindo da pasta do Dockerfile fornecida pelo usuário.
6. **Tag** local apontando para a URI ECR.
7. **Push** para o ECR.
8. **Relatório final** com digest, tamanho e URI publicada de cada imagem.

## Argumentos

- **Com uma ou mais URIs** (ex: `ecr-push 123.dkr.ecr.us-east-1.amazonaws.com/api:v1 123.dkr.ecr.us-east-1.amazonaws.com/web:v1`): processa cada URI em sequência.
- **Sem argumentos**: pergunte ao usuário quais URIs publicar. Não invente.

Para cada URI, **pergunte a pasta da app** (onde está o `Dockerfile`) antes de fazer o build, a menos que o usuário já tenha informado o mapeamento. Aceite os formatos:

- `URI` + perguntar pasta depois
- `URI=pasta` (ex: `123.dkr.ecr.us-east-1.amazonaws.com/api:v1=dvn-workshop-apps/backend/YoutubeLiveApp`)

## Formato esperado da URI

```
<account_id>.dkr.ecr.<region>.amazonaws.com/<repository>:<tag>
```

Exemplo: `407295215751.dkr.ecr.us-east-1.amazonaws.com/youtubeliveapp:v1.0.0`

Se a URI vier sem tag, **assuma `:latest`** mas avise o usuário (tag mutável + `:latest` é prática ruim; sugira uma tag versionada).

Se a URI estiver mal-formada, pare e peça correção.

## Pré-requisitos (verificar no início)

```bash
docker version --format '{{.Server.Version}}'   # docker daemon ativo
aws --version
aws sts get-caller-identity                     # credenciais válidas
```

Se qualquer comando falhar, **pare** e oriente o usuário:
- Docker não rodando → "Inicie o Docker Desktop"
- `aws sts get-caller-identity` falhou → "Configure suas credenciais AWS (`aws configure` ou `AWS_PROFILE`)"
- Account ID retornado **diferente** do `account_id` da URI → avise e peça confirmação antes de prosseguir.

## Workflow

### Passo 1 — Parse e validação
Para cada URI:
```
account_id  = parte antes do primeiro "."
region      = parte entre ".ecr." e ".amazonaws.com"
repo_tag    = parte após "amazonaws.com/"
repository  = parte antes do ":"
tag         = parte após ":" (ou "latest" se omitido)
```
Mostre ao usuário o parse de cada URI para confirmação visual antes de continuar.

### Passo 2 — Login no ECR (1x por `account_id`/`region`)
Agrupe URIs pelo par `(account_id, region)` para não repetir login.
```bash
aws ecr get-login-password --region <region> \
  | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com
```
Se o login falhar, pare e mostre o erro.

### Passo 3 — Garantir repositório ECR
Para cada `repository` único por `(account_id, region)`:
```bash
aws ecr describe-repositories \
  --repository-names <repository> \
  --region <region> >/dev/null 2>&1
```
Se retornar erro `RepositoryNotFoundException`:
- **Pergunte ao usuário** se deve criar.
- Se sim:
  ```bash
  aws ecr create-repository \
    --repository-name <repository> \
    --region <region> \
    --image-tag-mutability MUTABLE \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256
  ```
- Se não, pule essa URI e marque como falha no relatório final.

### Passo 4 — Build da imagem
A partir da pasta informada pelo usuário (onde está o `Dockerfile`):
```bash
docker build \
  --platform=linux/amd64 \
  --pull \
  -t <repository>:<tag> \
  <pasta-da-app>
```
- `--platform=linux/amd64` é obrigatório (importante em hosts ARM como Macs M-series).
- `--pull` garante base image fresca.
- Se houver `--build-arg` necessário, pergunte ao usuário antes.
- Se o build falhar, mostre o erro completo e **pare** essa URI (continue com as próximas).

### Passo 5 — Tag para o ECR
```bash
docker tag <repository>:<tag> <account_id>.dkr.ecr.<region>.amazonaws.com/<repository>:<tag>
```

### Passo 6 — Push
```bash
docker push <account_id>.dkr.ecr.<region>.amazonaws.com/<repository>:<tag>
```
Capture o digest retornado (`sha256:...`) para o relatório.

### Passo 7 — Cleanup local (opcional)
Não remova a imagem local automaticamente — o usuário pode querer reaproveitar. Se ele pedir, use:
```bash
docker rmi <repository>:<tag> <account_id>.dkr.ecr.<region>.amazonaws.com/<repository>:<tag>
```

## Múltiplas URIs

- Processe em **sequência** (não em paralelo) para evitar conflitos de auth/cache do Docker.
- Se uma URI falhar, **continue** com as próximas e reporte tudo no resumo final.
- Faça o login no ECR apenas uma vez por par único `(account_id, region)`.

## Relatório final

Para cada URI, apresente:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URI: 407295215751.dkr.ecr.us-east-1.amazonaws.com/youtubeliveapp:v1.0.0
Pasta: dvn-workshop-apps/backend/YoutubeLiveApp
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Repo ECR    — existe
✓ Build       — OK (linux/amd64, 112 MB)
✓ Tag         — OK
✓ Push        — OK
  digest: sha256:abc123...
  layers:  6 enviadas, 2 reusadas
```

E um sumário ao final:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Resumo: 3 imagens processadas
✓ youtubeliveapp:v1.0.0     — push OK
✓ youtube-live-app:v1.0.0   — push OK
✗ data-pipeline:v1.0.0      — build falhou
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Boas práticas reforçadas

- **Nunca** use `:latest` como tag única em produção. Sugira sempre uma tag imutável (semver, SHA do commit, ou data + SHA).
- **Nunca** faça push de uma imagem que não passou pelo `dockerize-app` (ou equivalente) — multi-stage, não-root, healthcheck etc.
- **Não** armazene credenciais AWS no Dockerfile ou em build args.
- **Confirme** o `account_id` da URI bate com `aws sts get-caller-identity` antes de fazer push — push pra conta errada é difícil de reverter.
- Se a região da URI for diferente de `us-east-1` (default do projeto), avise o usuário.

## Erros comuns

- **`no basic auth credentials`** → o login expirou ou não foi feito para o registry correto. Refaça `aws ecr get-login-password | docker login ...`.
- **`denied: User: arn:aws:iam::... is not authorized to perform: ecr:...`** → falta permissão IAM. Mostre o erro literal ao usuário; não tente contornar.
- **`exec format error` no runtime** → imagem foi buildada para a arquitetura errada. Garanta que `--platform=linux/amd64` foi passado no build.
- **`RepositoryNotFoundException`** → trate conforme Passo 3.
- **`ImagePushFailed` / `EOF`** → push interrompido (rede). Sugira retry; não retry automaticamente sem confirmação.
