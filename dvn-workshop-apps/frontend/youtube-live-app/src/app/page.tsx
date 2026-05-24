export const dynamic = "force-dynamic";

type Item = { title: string; detail: string };
type Section = { tag: string; title: string; subtitle: string; items: Item[] };
type Forecast = {
  date: string;
  temperatureC: number;
  temperatureF: number;
  summary: string;
  deployment: string;
};
type BackendResult =
  | { ok: true; data: Forecast[]; latencyMs: number; source: string }
  | { ok: false; error: string; source: string };

const BACKEND_URL =
  process.env.BACKEND_URL ??
  "http://youtubeliveapp.youtube-live.svc.cluster.local/backend/WeatherForecast";

async function fetchBackend(): Promise<BackendResult> {
  const started = Date.now();
  try {
    const res = await fetch(BACKEND_URL, {
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) {
      return {
        ok: false,
        error: `HTTP ${res.status} ${res.statusText}`,
        source: BACKEND_URL,
      };
    }
    const data = (await res.json()) as Forecast[];
    return { ok: true, data, latencyMs: Date.now() - started, source: BACKEND_URL };
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : String(err),
      source: BACKEND_URL,
    };
  }
}

const sections: Section[] = [
  {
    tag: "01 · IaC",
    title: "Infrastructure as Code com Terraform",
    subtitle:
      "Quatro stacks independentes, state remoto em S3 com native locking, providers fixados em ~> 6.0.",
    items: [
      {
        title: "00 · remote-backend",
        detail:
          "Bucket S3 dvn-workshop-production-terraform-state-407295215751 com versionamento, encryption AES256 e use_lockfile=true (sem DynamoDB).",
      },
      {
        title: "01 · networking",
        detail:
          "VPC 10.0.0.0/24 em 2 AZs, subnets pública/privada, NAT Gateway único, Flow Logs em CloudWatch com retention.",
      },
      {
        title: "02 · eks",
        detail:
          "Cluster EKS 1.33 dvn-workshop-production, 2× t4g.small ARM (AL2023), addons vpc-cni / coredns / kube-proxy / eks-pod-identity-agent, Access Entry por IAM.",
      },
      {
        title: "03 · cicd",
        detail:
          "GitHub OIDC provider + 2 IAM roles (CI sem perms, deploy com perms mínimas escopadas por ARN), Access Entry EKS com AmazonEKSEditPolicy no namespace youtube-live.",
      },
    ],
  },
  {
    tag: "02 · Apps + Containers",
    title: "Backend .NET 8 e Frontend Next.js 14",
    subtitle:
      "Dockerfiles multi-stage, base Alpine, usuário não-root UID 10001, HEALTHCHECK, .dockerignore, imagens ARM64 publicadas no ECR.",
    items: [
      {
        title: "Backend · ASP.NET Core 8",
        detail:
          "mcr.microsoft.com/dotnet/aspnet:8.0-alpine, 47 MB, expõe /backend/health e /backend/WeatherForecast em :8080. ClusterIP interno.",
      },
      {
        title: "Frontend · Next.js 14",
        detail:
          "node:20-alpine + output 'standalone', 53 MB, route handler /api/health, exposto via Service type=LoadBalancer (Classic ELB).",
      },
      {
        title: "ECR + tag :SHA",
        detail:
          "Repos com scan-on-push, encryption AES256. Tag = SHA curto do commit (imutável) garante rastreabilidade do build até produção.",
      },
      {
        title: "Skills automatizadas",
        detail:
          "/dockerize-app gera Dockerfile + .dockerignore + smoke. /ecr-push faz build+login+push de N URIs. Validadas ponta-a-ponta nesta sessão.",
      },
    ],
  },
  {
    tag: "03 · Kubernetes",
    title: "Manifestos com boas práticas obrigatórias",
    subtitle:
      "Tudo segue a rule kubernetes-manifest-conventions.md: labels app.kubernetes.io/*, replicas ≥ 2, PDB, probes, security context restrito.",
    items: [
      {
        title: "Deployments resilientes",
        detail:
          "2 réplicas, RollingUpdate maxUnavailable=0, topologySpreadConstraints por zona, nodeSelector arm64 pra fail-fast, terminationGracePeriodSeconds + preStop sleep.",
      },
      {
        title: "Probes",
        detail:
          "readinessProbe estrita e livenessProbe leniente em /backend/health e /api/health. Cada container declara ambas — sem exceção.",
      },
      {
        title: "Security context",
        detail:
          "runAsNonRoot, UID/GID 10001, readOnlyRootFilesystem com emptyDir em /tmp, drop ALL capabilities, seccompProfile=RuntimeDefault.",
      },
      {
        title: "PodDisruptionBudget",
        detail:
          "maxUnavailable=1 em ambos os apps — drenar 1 node por vez sem derrubar o serviço. ALLOWED DISRUPTIONS=1 verificado.",
      },
    ],
  },
  {
    tag: "04 · CI/CD",
    title: "Pipeline commit → produção sem kubectl manual",
    subtitle:
      "GitHub Actions usando OIDC (sem long-lived secret), trust policy com StringEquals no sub claim, build ARM64 com cache GHA, deploy via kubectl set image + rollout undo automático em falha.",
    items: [
      {
        title: "Trigger",
        detail:
          "Push em main com paths-filter. PRs assumem role CI sem perms reais — só validate. Concurrency group por app+ref cancela runs obsoletos.",
      },
      {
        title: "Build",
        detail:
          "docker buildx --platform=linux/arm64 --push --cache-from type=gha --cache-to type=gha,mode=max. Tag = ${GITHUB_SHA:0:7}.",
      },
      {
        title: "Deploy",
        detail:
          "aws eks update-kubeconfig → kubectl set image deployment/<x> app=<uri>:<sha> -n youtube-live → kubectl rollout status --timeout=180s.",
      },
      {
        title: "Rollback",
        detail:
          "if failure(): kubectl rollout undo + exit 1. Sem intervenção humana pra reverter um deploy quebrado. Esta página é prova de que rolou.",
      },
    ],
  },
];

const stats = [
  { value: "4", label: "Stacks Terraform" },
  { value: "4", label: "ADRs + IMPL records" },
  { value: "2", label: "Apps · 2 imagens ARM64" },
  { value: "2", label: "IAM roles · OIDC" },
  { value: "0", label: "kubectl manual em prod" },
];

export default async function Home() {
  const backend = await fetchBackend();

  return (
    <main className="min-h-screen bg-gradient-to-b from-zinc-950 via-zinc-900 to-zinc-950 text-zinc-100">
      <header className="border-b border-zinc-800/60 bg-zinc-950/60 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <p className="font-mono text-xs sm:text-sm">
            <code className="rounded-md border border-zinc-700 bg-zinc-900/80 px-2 py-1">
              Workshop DevOps na Nuvem Especial v2
            </code>
          </p>
          <p className="hidden font-mono text-xs text-zinc-500 sm:block">
            EKS 1.33 · t4g.small · us-east-1
          </p>
        </div>
      </header>

      <section className="mx-auto max-w-6xl px-6 pb-12 pt-16 sm:pt-24">
        <p className="font-mono text-xs uppercase tracking-widest text-sky-400">
          dvn-workshop-production
        </p>
        <h1 className="mt-3 text-4xl font-semibold leading-tight tracking-tight sm:text-5xl">
          O que foi construído neste workshop
        </h1>
        <p className="mt-5 max-w-3xl text-base text-zinc-400 sm:text-lg">
          Esta página foi <span className="text-zinc-200">publicada pelo próprio pipeline</span> que
          construímos: commit em <code className="rounded bg-zinc-800/80 px-1.5 py-0.5 font-mono text-sm text-zinc-200">main</code> →
          GitHub Actions (OIDC) → build ARM64 → push pro ECR → <code className="rounded bg-zinc-800/80 px-1.5 py-0.5 font-mono text-sm text-zinc-200">kubectl set image</code> →
          rollout no EKS. Se você está vendo, o loop fechou.
        </p>

        <dl className="mt-12 grid grid-cols-2 gap-4 sm:grid-cols-5">
          {stats.map((s) => (
            <div
              key={s.label}
              className="rounded-lg border border-zinc-800 bg-zinc-900/40 px-4 py-5 text-center"
            >
              <dt className="text-3xl font-semibold text-sky-300 sm:text-4xl">{s.value}</dt>
              <dd className="mt-2 text-xs font-medium uppercase tracking-wider text-zinc-500">
                {s.label}
              </dd>
            </div>
          ))}
        </dl>
      </section>

      <section className="mx-auto max-w-6xl px-6 pb-12">
        <article
          className={`rounded-2xl border p-6 sm:p-8 ${
            backend.ok
              ? "border-emerald-900/60 bg-emerald-950/20"
              : "border-rose-900/60 bg-rose-950/20"
          }`}
        >
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="font-mono text-xs uppercase tracking-widest text-emerald-400">
                live · server-side fetch · this render
              </p>
              <h2 className="mt-2 text-2xl font-semibold sm:text-3xl">
                {backend.ok
                  ? "Frontend ↔ backend: conexão ok"
                  : "Frontend ↔ backend: indisponível"}
              </h2>
              <p className="mt-2 font-mono text-xs text-zinc-500 break-all">
                GET {backend.source}
              </p>
            </div>
            <span
              className={`shrink-0 rounded-full px-3 py-1 font-mono text-xs font-semibold ${
                backend.ok
                  ? "bg-emerald-500/15 text-emerald-300"
                  : "bg-rose-500/15 text-rose-300"
              }`}
            >
              {backend.ok ? `HTTP 200 · ${backend.latencyMs}ms` : "FAILED"}
            </span>
          </div>

          {backend.ok ? (
            <>
              <p className="mt-4 text-sm text-zinc-400">
                Este pod do frontend resolveu{" "}
                <code className="rounded bg-zinc-800/80 px-1.5 py-0.5 font-mono text-xs text-zinc-200">
                  youtubeliveapp.youtube-live.svc.cluster.local
                </code>{" "}
                via CoreDNS, falou com o Service ClusterIP do backend, recebeu JSON do{" "}
                <code className="rounded bg-zinc-800/80 px-1.5 py-0.5 font-mono text-xs text-zinc-200">
                  WeatherForecastController
                </code>{" "}
                e renderizou abaixo. Sem chamada externa, sem ELB no meio.
              </p>
              <div className="mt-5 overflow-hidden rounded-lg border border-zinc-800">
                <table className="w-full text-left text-sm">
                  <thead className="bg-zinc-900/80 font-mono text-xs uppercase tracking-wider text-zinc-500">
                    <tr>
                      <th className="px-4 py-2.5">date</th>
                      <th className="px-4 py-2.5">°C</th>
                      <th className="px-4 py-2.5">°F</th>
                      <th className="px-4 py-2.5">summary</th>
                      <th className="px-4 py-2.5">deployment</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-zinc-800/70 bg-zinc-950/40">
                    {backend.data.map((f, i) => (
                      <tr key={`${f.date}-${i}`}>
                        <td className="px-4 py-2.5 font-mono text-xs text-zinc-300">
                          {f.date}
                        </td>
                        <td className="px-4 py-2.5 font-mono text-zinc-200">
                          {f.temperatureC}
                        </td>
                        <td className="px-4 py-2.5 font-mono text-zinc-400">
                          {f.temperatureF}
                        </td>
                        <td className="px-4 py-2.5 text-zinc-200">{f.summary}</td>
                        <td className="px-4 py-2.5 font-mono text-xs">
                          <span className="rounded bg-sky-500/15 px-2 py-0.5 text-sky-300">
                            {f.deployment}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          ) : (
            <div className="mt-4 space-y-3">
              <p className="text-sm text-zinc-400">
                Frontend tentou falar com o backend e falhou. Provavelmente: pod do backend
                não-Ready, ClusterIP não resolve (CoreDNS), ou o Service não casa labels.
                Esta página é render dinâmico — recarregue depois de corrigir.
              </p>
              <pre className="overflow-x-auto rounded-lg border border-rose-900/60 bg-rose-950/40 p-3 font-mono text-xs text-rose-200">
                {backend.error}
              </pre>
            </div>
          )}
        </article>
      </section>

      <section className="mx-auto max-w-6xl space-y-12 px-6 pb-24">
        {sections.map((section) => (
          <article
            key={section.tag}
            className="rounded-2xl border border-zinc-800 bg-zinc-900/30 p-6 sm:p-8"
          >
            <p className="font-mono text-xs uppercase tracking-widest text-sky-400">
              {section.tag}
            </p>
            <h2 className="mt-2 text-2xl font-semibold sm:text-3xl">{section.title}</h2>
            <p className="mt-3 max-w-3xl text-sm text-zinc-400 sm:text-base">
              {section.subtitle}
            </p>
            <ul className="mt-6 grid gap-4 sm:grid-cols-2">
              {section.items.map((item) => (
                <li
                  key={item.title}
                  className="rounded-lg border border-zinc-800/80 bg-zinc-950/40 p-4"
                >
                  <p className="text-sm font-semibold text-zinc-100">{item.title}</p>
                  <p className="mt-1.5 text-sm leading-relaxed text-zinc-400">{item.detail}</p>
                </li>
              ))}
            </ul>
          </article>
        ))}
      </section>

      <footer className="border-t border-zinc-800/60 bg-zinc-950/60">
        <div className="mx-auto max-w-6xl px-6 py-6 font-mono text-xs text-zinc-500">
          <p>
            backend:{" "}
            <code className="text-zinc-300">
              youtubeliveapp.youtube-live.svc.cluster.local
            </code>{" "}
            (ClusterIP) · frontend: este host (Service LoadBalancer)
          </p>
          <p className="mt-1">
            agora: você está em um pod servido por <code className="text-zinc-300">node:20-alpine</code>{" "}
            rodando como UID 10001 num t4g.small ARM em uma das duas AZs do cluster.
          </p>
        </div>
      </footer>
    </main>
  );
}
