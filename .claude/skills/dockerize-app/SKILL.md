---
name: dockerize-app
description: Gera um Dockerfile production-ready para uma aplicação a partir do caminho da pasta onde ela está. Detecta automaticamente a linguagem/framework (Node.js, Next.js, .NET, Python, Go, Java, etc.), aplica boas práticas de segurança e tamanho (multi-stage build, base Alpine ou distroless, usuário não-root/rootless, HEALTHCHECK, .dockerignore), faz o build da imagem para `linux/amd64`, sobe o container, testa o endpoint de health check e mata o container ao final. Use esta skill sempre que o usuário pedir para "dockerizar", "containerizar", "criar Dockerfile", "gerar imagem Docker" ou "subir num container" — mesmo que não mencione explicitamente "dockerize-app". Recebe como argumento o caminho da pasta da app (ex: `dvn-workshop-apps/backend/YoutubeLiveApp`); se nenhum caminho for passado, pergunte ao usuário qual app dockerizar.
---

## O que esta skill faz

Para uma pasta de aplicação informada pelo usuário:

1. **Detecta a linguagem/framework** lendo arquivos marcadores (`package.json`, `*.csproj`, `pyproject.toml`, `go.mod`, `pom.xml`, etc.).
2. **Gera um `Dockerfile` production-ready** dentro da pasta da app, aplicando todas as boas práticas listadas abaixo.
3. **Gera (ou atualiza) um `.dockerignore`** na mesma pasta.
4. **Faz o build da imagem** para `linux/amd64` (independentemente da arquitetura do host).
5. **Sobe o container** mapeando a porta de saúde.
6. **Faz polling no endpoint de health check** até retornar 2xx (timeout 60s).
7. **Mata e remove o container** ao final, sucesso ou falha.

## Argumentos

- **Com argumento** (ex: `dockerize-app dvn-workshop-apps/backend/YoutubeLiveApp`): roda o fluxo para essa pasta.
- **Sem argumento**: pergunte ao usuário qual app dockerizar antes de prosseguir. Não tente adivinhar.

## Detecção de linguagem/framework

Inspecione a pasta da app e identifique o stack pelo primeiro marcador encontrado:

| Marcador                                          | Stack                  | Base sugerida (runtime)                              |
|---------------------------------------------------|------------------------|------------------------------------------------------|
| `package.json` com `"next"` em deps               | Next.js                | `node:20-alpine` (build) → `node:20-alpine` (run, standalone output) |
| `package.json` com `"@nestjs/core"` em deps       | NestJS                 | `node:20-alpine` (build) → `node:20-alpine` (run)    |
| `package.json` (genérico)                         | Node.js                | `node:20-alpine` (build) → `node:20-alpine` (run)    |
| `*.csproj` / `*.sln`                              | .NET                   | `mcr.microsoft.com/dotnet/sdk:8.0-alpine` (build) → `mcr.microsoft.com/dotnet/aspnet:8.0-alpine` (run) |
| `pyproject.toml` / `requirements.txt`             | Python                 | `python:3.12-alpine` (build) → `python:3.12-alpine` (run) |
| `go.mod`                                          | Go                     | `golang:1.22-alpine` (build) → `gcr.io/distroless/static-debian12:nonroot` (run) |
| `pom.xml` / `build.gradle*`                       | Java                   | `eclipse-temurin:21-jdk-alpine` (build) → `eclipse-temurin:21-jre-alpine` (run) |
| `Cargo.toml`                                      | Rust                   | `rust:1-alpine` (build) → `gcr.io/distroless/static-debian12:nonroot` (run) |

Se nenhum marcador for encontrado, **pare e pergunte ao usuário** qual stack/runtime ele quer.

Para Next.js, verifique se `next.config.*` já tem `output: 'standalone'`. Se não tiver, **avise o usuário** e peça confirmação para adicionar (a imagem ficará muito menor com standalone).

## Boas práticas obrigatórias

Todo Dockerfile gerado **DEVE**:

1. **Multi-stage build** — separar `builder` (com SDK/toolchain) de `runtime` (apenas o necessário para rodar). O estágio final nunca contém compiladores, gerenciadores de pacote dev ou source code além do artefato final.
2. **Base mínima** — Alpine para a maioria dos stacks; distroless `nonroot` para Go/Rust (binários estáticos). Nunca use tags `latest`, sempre pin de versão major.minor.
3. **Usuário não-root** — criar um usuário/grupo dedicado (ex: `appuser:appgroup`, UID/GID `10001`) e usar `USER appuser` antes do `ENTRYPOINT`. Não rode como root sob nenhuma hipótese no estágio final.
4. **Rootless-friendly** — todos os arquivos copiados devem pertencer ao usuário não-root (`COPY --chown=appuser:appgroup`). A porta exposta deve ser >= 1024 (não-privilegiada). Se o framework expõe 80/443 por padrão, mude para 8080/8443 via variável de ambiente.
5. **HEALTHCHECK** — instrução `HEALTHCHECK` no Dockerfile chamando o endpoint de saúde da app (ver tabela abaixo). Use `wget`/`curl` quando disponível na base; em distroless use o próprio binário da app ou exclua o HEALTHCHECK do Dockerfile e dependa só do orquestrador.
6. **Linux/amd64 explícito** — Dockerfile não precisa de `--platform`, mas o `docker build` deve passar `--platform=linux/amd64` para garantir a arquitetura, independentemente do host (importante: Macs ARM geram amd64 via emulação).
7. **`.dockerignore`** — sempre gerar/atualizar para excluir `node_modules`, `bin/`, `obj/`, `.git`, `.env*`, `**/*.md`, `dist/`, `target/`, etc., conforme o stack.
8. **Sem secrets** — nunca embutir credenciais, tokens ou `.env` na imagem. Variáveis sensíveis vêm via env do runtime.
9. **Layer caching** — copiar manifestos de dependência (`package.json`, `*.csproj`, `go.mod`, etc.) e instalar dependências **antes** de copiar o source code, para maximizar reuso de cache.
10. **`ENTRYPOINT` em forma exec** — usar a forma JSON `ENTRYPOINT ["binário", "arg"]`, nunca shell form.
11. **Sem `apt-get update` órfão** — se instalar pacotes do sistema, sempre `--no-cache` no Alpine ou `&& rm -rf /var/lib/apt/lists/*` no Debian, no mesmo `RUN`.

## Endpoints de health check padrão

Use o seguinte como default ao gerar o `HEALTHCHECK` e ao testar:

| Stack              | Porta default | Path default     | Observação                                                  |
|--------------------|---------------|------------------|-------------------------------------------------------------|
| Next.js            | 3000          | `/api/health` ou `/` | Crie um route handler em `/api/health` se não existir (apenas avise) |
| NestJS             | 3000          | `/health`        | Confirme com o usuário se a app usa `@nestjs/terminus`      |
| Node.js genérico   | 3000          | `/health`        | Pergunte ao usuário a porta/path se não for óbvio           |
| .NET (ASP.NET)     | 8080          | `/health`        | Pergunte se app tem `app.MapHealthChecks("/health")`        |
| Python (FastAPI)   | 8000          | `/health`        |                                                             |
| Python (Flask)     | 5000          | `/health`        |                                                             |
| Go                 | 8080          | `/health`        |                                                             |
| Java (Spring Boot) | 8080          | `/actuator/health` |                                                           |

Antes de gerar o Dockerfile, **pergunte ao usuário** se a porta/path acima estão corretos para a app dele. Se a app não tiver endpoint de health, **avise** que o usuário precisa criar um — gere o Dockerfile mesmo assim, mas marque que o teste de health vai falhar.

## Workflow

### Passo 1 — Discovery
- Liste os arquivos da raiz da pasta passada.
- Identifique o stack pelos marcadores.
- Leia o arquivo principal de manifesto (ex: `package.json`, `*.csproj`) para extrair nome, versão, framework target e scripts/entrypoint.
- Confirme com o usuário: porta da app, path de health check, e nome da imagem a ser gerada (default: `<nome-da-pasta>:local`).

### Passo 2 — Geração de arquivos
- Escreva o `Dockerfile` na raiz da pasta da app, aplicando todas as boas práticas obrigatórias.
- Escreva/atualize o `.dockerignore` na mesma pasta.
- Mostre o conteúdo gerado para o usuário antes de fazer o build.

### Passo 3 — Build
```bash
docker build \
  --platform=linux/amd64 \
  -t <nome-da-imagem>:local \
  <caminho-da-pasta>
```
Capture o output. Se falhar, mostre a mensagem de erro e **pare**.

### Passo 4 — Run
```bash
docker run -d \
  --name <nome-da-imagem>-healthcheck \
  --platform=linux/amd64 \
  -p <porta-host>:<porta-container> \
  <nome-da-imagem>:local
```
Escolha uma porta de host livre (default: igual à do container; se ocupada, incremente).

### Passo 5 — Poll health check
- Faça polling em `http://localhost:<porta-host><path-health>` a cada 2 segundos.
- Timeout total: 60 segundos.
- Considere sucesso qualquer resposta com status code 2xx.
- Em paralelo, monitore o status do container (`docker inspect --format='{{.State.Status}}'`). Se o container sair antes do health check passar, capture os logs (`docker logs`) e mostre ao usuário.

### Passo 6 — Cleanup (sempre executar, sucesso ou falha)
```bash
docker stop <nome-da-imagem>-healthcheck >/dev/null 2>&1 || true
docker rm   <nome-da-imagem>-healthcheck >/dev/null 2>&1 || true
```

### Passo 7 — Relatório final
Apresente um bloco de status no formato:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
App: dvn-workshop-apps/backend/YoutubeLiveApp
Stack detectado: .NET 8 (ASP.NET Core)
Imagem: youtubeliveapp:local
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Dockerfile     — gerado (multi-stage, alpine, USER appuser:10001)
✓ .dockerignore  — gerado
✓ Build          — OK (linux/amd64, tamanho final: 112 MB)
✓ Run            — container subiu (porta 8080)
✓ Health check   — GET /health → 200 em 4.2s
✓ Cleanup        — container parado e removido
```

Se houver erro em qualquer passo, marque com `✗` e exiba a mensagem.

## Templates de Dockerfile por stack

Use estes como ponto de partida — adapte conforme os scripts/dependências reais da app.

### Next.js (com `output: 'standalone'`)

```dockerfile
# syntax=docker/dockerfile:1.7
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN --mount=type=cache,target=/root/.npm npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
RUN addgroup -g 10001 -S appgroup \
 && adduser  -u 10001 -S appuser -G appgroup
COPY --from=builder --chown=appuser:appgroup /app/public          ./public
COPY --from=builder --chown=appuser:appgroup /app/.next/standalone ./
COPY --from=builder --chown=appuser:appgroup /app/.next/static     ./.next/static
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/api/health || exit 1
ENTRYPOINT ["node", "server.js"]
```

### .NET 8 (ASP.NET Core)

```dockerfile
# syntax=docker/dockerfile:1.7
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish \
    --no-restore \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true
RUN apk add --no-cache wget \
 && addgroup -g 10001 -S appgroup \
 && adduser  -u 10001 -S appuser -G appgroup
COPY --from=build --chown=appuser:appgroup /app/publish ./
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1
ENTRYPOINT ["dotnet", "YoutubeLiveApp.dll"]
```

> Substitua `YoutubeLiveApp.dll` pelo nome real do assembly (extraído do `.csproj`).

### Python (FastAPI/uvicorn)

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-alpine AS build
WORKDIR /app
RUN apk add --no-cache build-base
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-alpine AS runtime
WORKDIR /app
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000
RUN apk add --no-cache wget \
 && addgroup -g 10001 -S appgroup \
 && adduser  -u 10001 -S appuser -G appgroup
COPY --from=build /install /usr/local
COPY --chown=appuser:appgroup . .
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8000/health || exit 1
ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Go (binário estático + distroless)

```dockerfile
# syntax=docker/dockerfile:1.7
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/app ./...

FROM gcr.io/distroless/static-debian12:nonroot AS runtime
WORKDIR /
COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```

> Distroless `nonroot` não inclui shell nem `wget`. Para HEALTHCHECK,
> ou (a) implemente um subcomando `app healthcheck` no próprio binário,
> ou (b) omita o HEALTHCHECK do Dockerfile e dependa do orquestrador.

## Template de `.dockerignore`

Adapte ao stack. Base comum:

```
.git
.gitignore
.dockerignore
Dockerfile*
**/.env
**/.env.*
**/node_modules
**/dist
**/build
**/bin
**/obj
**/target
**/.next
**/.nuxt
**/__pycache__
**/*.pyc
**/.venv
**/.idea
**/.vscode
**/*.md
**/README*
**/LICENSE*
**/.DS_Store
```

## Erros comuns a evitar

- **Não** copie `.env` para dentro da imagem (mesmo que esteja no `.gitignore`, o `COPY . .` traz tudo que não está no `.dockerignore`).
- **Não** rode `npm install` no estágio runtime — use `npm ci --omit=dev` apenas se precisar de deps de runtime, e idealmente já no estágio builder.
- **Não** use `EXPOSE 80`/`EXPOSE 443` — exige privilégios; mantenha portas >= 1024.
- **Não** esqueça de mudar o `ENTRYPOINT` para forma exec — shell form (`ENTRYPOINT comando arg`) gera um PID 1 que não propaga sinais (SIGTERM) corretamente.
- **Não** misture `ENTRYPOINT` e `CMD` sem entender o contrato — para esta skill, prefira só `ENTRYPOINT` na forma exec.
- **Não** assuma que o teste de health passou só porque o container está `running` — sempre verifique HTTP 2xx no endpoint real.
