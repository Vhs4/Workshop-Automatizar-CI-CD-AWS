# Convenções para Manifestos Kubernetes

Regras obrigatórias para gerar manifestos de workloads (Deployments, StatefulSets, DaemonSets, etc.). Toda geração de YAML para o cluster EKS deste projeto deve seguir estas convenções. Não invente atalhos — se não souber um valor, **pergunte ao usuário** antes de gerar o manifesto.

---

## 1. Labels padronizadas (obrigatórias em todo recurso)

Use o conjunto de [labels recomendadas pelo Kubernetes](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/) em **todo** recurso (Deployment, Service, PDB, ConfigMap, Secret, etc.). Sem exceções.

```yaml
metadata:
  labels:
    app.kubernetes.io/name: <nome-da-app>           # ex: youtubeliveapp
    app.kubernetes.io/instance: <release-name>      # ex: youtubeliveapp-prod
    app.kubernetes.io/version: "<versão-da-imagem>" # ex: "1.4.0" — sempre string
    app.kubernetes.io/component: <papel>            # ex: api, web, worker, db
    app.kubernetes.io/part-of: <sistema-maior>      # ex: youtube-live-platform
    app.kubernetes.io/managed-by: <ferramenta>      # ex: helm, kustomize, terraform
```

**Regras**:
- Toda label deve ser válida em RFC 1123 (lowercase, alfanumérico, `-`).
- `app.kubernetes.io/version` é **sempre string** entre aspas (versões com ponto seriam interpretadas como float).
- O conjunto deve ser **idêntico** entre o Deployment, seu Service, seu PDB e qualquer ConfigMap/Secret próprio dele.
- O `spec.selector.matchLabels` do Deployment e o `spec.selector` do Service usam um **subconjunto imutável**: apenas `app.kubernetes.io/name` + `app.kubernetes.io/instance` + `app.kubernetes.io/component`. Nunca incluir `version` no selector (impede rolling updates).

---

## 2. Namespaces

- **Nunca** use o namespace `default` para workloads de aplicação.
- Crie um namespace dedicado por sistema/produto (ex: `youtube-live`), declarado explicitamente em `metadata.namespace` de **todo** recurso.
- O namespace também recebe as labels padronizadas (`part-of`, `managed-by`).

---

## 3. Deployments — regras mínimas

### 3.1 Réplicas
- **Mínimo `replicas: 2`** para qualquer Deployment. Réplica única não é aceitável fora de jobs/dev — mesmo em ambientes pequenos.
- Se a workload precisa de mais (alto tráfego), defina via HPA, não chumbado.

### 3.2 Estratégia de rollout
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0   # zero downtime durante updates
```

### 3.3 Probes (obrigatórias: readiness E liveness)
**Todo container** deve declarar `readinessProbe` e `livenessProbe`. Sem exceções.

```yaml
readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 30
  periodSeconds: 20
  timeoutSeconds: 2
  failureThreshold: 3
```

**Regras**:
- `readinessProbe` deve ser **estrita** (a app só recebe tráfego quando puder responder de verdade — incluindo deps externas críticas como DB).
- `livenessProbe` deve ser **leniente** (só reinicia se a app travou de verdade — nunca acople a dependências externas, ou um outage de DB derruba todos os pods).
- Endpoints `/health/ready` e `/health/live` devem ser **distintos**. Se a app só expõe `/health`, peça para o time separar antes de gerar o manifesto.
- Para apps com startup lento (.NET cold-start, JVM), adicione `startupProbe` para evitar kill prematuro pela `livenessProbe`.

### 3.4 Resources (obrigatórios)
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi          # SEMPRE definir limit de memória
    # cpu: <opcional>      # evitar limit de CPU — pode causar throttling injusto
```

**Regras**:
- `requests.cpu` e `requests.memory` são **obrigatórios** (definem o agendamento e a qualidade de serviço).
- `limits.memory` é **obrigatório** (sem ele, um pod com leak pode derrubar o node inteiro).
- `limits.cpu` é **desencorajado** salvo justificativa clara (CFS throttling em apps multi-thread costuma piorar latência mais do que ajuda).

### 3.5 Security context (obrigatório)
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
```

Se a app precisa escrever em disco (logs, cache), monte `emptyDir` apenas nos paths necessários — não desabilite `readOnlyRootFilesystem`.

### 3.6 Imagens
- **Nunca** use tag `:latest`. Use semver ou SHA imutável (ex: `v1.4.0`, `sha256:abc...`).
- Sempre `imagePullPolicy: IfNotPresent` (para tags imutáveis); `Always` apenas se a tag for mutável (não recomendado).
- A imagem **deve** ter sido publicada pelo workflow `ecr-push` ou equivalente — multi-stage, não-root, HEALTHCHECK.

### 3.7 Alta disponibilidade
Para qualquer Deployment com `replicas >= 2`, espalhe os pods entre zonas:

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: <nome>
        app.kubernetes.io/instance: <instance>
```

### 3.8 Graceful shutdown
```yaml
terminationGracePeriodSeconds: 30
containers:
  - name: app
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 10"]   # drenar conexões antes de morrer
```

---

## 4. Service (obrigatório com todo Deployment)

**Toda vez** que criar um Deployment, gere também um Service do tipo **NodePort** apontando pra ele.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <nome-da-app>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <nome>
    app.kubernetes.io/instance: <instance>
    app.kubernetes.io/component: <papel>
    app.kubernetes.io/part-of: <sistema>
    app.kubernetes.io/managed-by: <ferramenta>
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: <nome>
    app.kubernetes.io/instance: <instance>
    app.kubernetes.io/component: <papel>
  ports:
    - name: http
      protocol: TCP
      port: 80                # porta do Service (ClusterIP)
      targetPort: http        # nome da porta no container, não número
      nodePort: 30080         # opcional; deixe Kubernetes alocar se não tem motivo pra fixar
```

**Regras**:
- O `targetPort` deve referenciar a porta **por nome** (ex: `http`), não por número. Isso desacopla o Service de mudanças de porta no container.
- O container deve declarar a porta com `name: http` (ou equivalente).
- Use NodePort por padrão neste projeto (workshop / EKS sem ingress controller dedicado). Para produção real, migre para `ClusterIP` + Ingress.
- Não fixe `nodePort` salvo necessidade clara — colisões entre Services são silenciosas e dolorosas.

---

## 5. PodDisruptionBudget (obrigatório com todo Deployment)

**Toda vez** que criar um Deployment com `replicas >= 2`, gere um PDB:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <nome-da-app>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <nome>
    app.kubernetes.io/instance: <instance>
    app.kubernetes.io/component: <papel>
    app.kubernetes.io/part-of: <sistema>
    app.kubernetes.io/managed-by: <ferramenta>
spec:
  minAvailable: 1                      # ou: maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: <nome>
      app.kubernetes.io/instance: <instance>
      app.kubernetes.io/component: <papel>
```

**Regras**:
- Use **`minAvailable`** ou **`maxUnavailable`** — nunca os dois.
- Para `replicas = 2`, use `maxUnavailable: 1` (permite drenar 1 node por vez).
- Para `replicas >= 3`, prefira `minAvailable: <replicas - 1>` ou `maxUnavailable: 1`.
- **Nunca** use `minAvailable: 100%` com `replicas: 1` — bloqueia drains de node e quebra cluster autoscaler.

---

## 6. ConfigMaps e Secrets

- Nunca embuta valores de configuração diretamente em `env:` literais quando forem múltiplos — agrupe em `ConfigMap` referenciado via `envFrom`.
- Secrets **nunca** vão em ConfigMap. Use `kind: Secret` ou (preferido) referencie via [External Secrets Operator](https://external-secrets.io/) apontando para AWS Secrets Manager / SSM Parameter Store.
- Nunca commite valores de Secret em texto puro no Git. Use Sealed Secrets, External Secrets ou SOPS.

---

## 7. Estrutura de arquivos

Para cada workload, gere um arquivo por kind, agrupados na pasta da app:

```
k8s/<app>/
├── 00-namespace.yaml
├── 10-deployment.yaml
├── 20-service.yaml
├── 30-pdb.yaml
├── 40-configmap.yaml          # se houver
├── 50-hpa.yaml                # se houver
└── kustomization.yaml         # se usando Kustomize
```

O prefixo numérico garante ordem de apply previsível (`kubectl apply -f k8s/<app>/` aplica em ordem alfabética).

---

## 8. apiVersion — sempre validar

Antes de gerar qualquer manifesto, confirme o `apiVersion` correto via MCP `awslabs.eks-mcp-server` (`list_api_versions`). A versão do cluster EKS deste projeto é a definida em `dvn-workshop-terraform/02-eks-stack-ai/variables.tf` (`eks.cluster_version`). Não use `apiVersion` lembrado de memória — ele muda entre versões do Kubernetes.

---

## 9. Checklist de revisão (rodar antes de aplicar)

Antes de propor um manifesto ao usuário, verifique mentalmente:

- [ ] Tem todas as 6 labels `app.kubernetes.io/*`?
- [ ] Namespace é dedicado (não `default`)?
- [ ] `replicas >= 2`?
- [ ] `RollingUpdate` com `maxUnavailable: 0`?
- [ ] `readinessProbe` E `livenessProbe` em **todo** container?
- [ ] Endpoints de readiness e liveness são **diferentes**?
- [ ] `resources.requests` (cpu+mem) e `resources.limits.memory` definidos?
- [ ] `securityContext` com `runAsNonRoot`, `readOnlyRootFilesystem`, `drop: [ALL]`?
- [ ] Imagem com tag imutável (não `:latest`)?
- [ ] `topologySpreadConstraints` por zona?
- [ ] `terminationGracePeriodSeconds` + `preStop` para graceful shutdown?
- [ ] Service NodePort criado, com `targetPort` por **nome**?
- [ ] PDB criado, com `minAvailable` OU `maxUnavailable` (não ambos)?
- [ ] Nenhuma secret hardcoded?
- [ ] `apiVersion` validado contra a versão do cluster?

Se qualquer item está vermelho e não há justificativa explícita, **conserte antes de mostrar o manifesto ao usuário**.

---

## 10. Exemplo completo (referência)

Manifesto mínimo aceitável para uma API HTTP simples. Use como ponto de partida.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: youtube-live
  labels:
    app.kubernetes.io/part-of: youtube-live-platform
    app.kubernetes.io/managed-by: kustomize
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: youtubeliveapp
  namespace: youtube-live
  labels:
    app.kubernetes.io/name: youtubeliveapp
    app.kubernetes.io/instance: youtubeliveapp-prod
    app.kubernetes.io/version: "1.4.0"
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: youtube-live-platform
    app.kubernetes.io/managed-by: kustomize
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: youtubeliveapp
      app.kubernetes.io/instance: youtubeliveapp-prod
      app.kubernetes.io/component: api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: youtubeliveapp
        app.kubernetes.io/instance: youtubeliveapp-prod
        app.kubernetes.io/version: "1.4.0"
        app.kubernetes.io/component: api
        app.kubernetes.io/part-of: youtube-live-platform
        app.kubernetes.io/managed-by: kustomize
    spec:
      terminationGracePeriodSeconds: 30
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: youtubeliveapp
              app.kubernetes.io/instance: youtubeliveapp-prod
              app.kubernetes.io/component: api
      containers:
        - name: app
          image: 407295215751.dkr.ecr.us-east-1.amazonaws.com/youtubeliveapp:1.4.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          env:
            - name: ASPNETCORE_URLS
              value: http://+:8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              memory: 256Mi
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 30
            periodSeconds: 20
            timeoutSeconds: 2
            failureThreshold: 3
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 10"]
---
apiVersion: v1
kind: Service
metadata:
  name: youtubeliveapp
  namespace: youtube-live
  labels:
    app.kubernetes.io/name: youtubeliveapp
    app.kubernetes.io/instance: youtubeliveapp-prod
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: youtube-live-platform
    app.kubernetes.io/managed-by: kustomize
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: youtubeliveapp
    app.kubernetes.io/instance: youtubeliveapp-prod
    app.kubernetes.io/component: api
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: http
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: youtubeliveapp
  namespace: youtube-live
  labels:
    app.kubernetes.io/name: youtubeliveapp
    app.kubernetes.io/instance: youtubeliveapp-prod
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: youtube-live-platform
    app.kubernetes.io/managed-by: kustomize
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: youtubeliveapp
      app.kubernetes.io/instance: youtubeliveapp-prod
      app.kubernetes.io/component: api
```
