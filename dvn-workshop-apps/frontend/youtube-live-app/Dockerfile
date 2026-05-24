# syntax=docker/dockerfile:1.7
# Multi-stage build for youtube-live-app (Next.js 14, app router, standalone output).
# Final image: node:20-alpine, non-root user (UID 10001), listens on :3000,
# HEALTHCHECK hits /api/health (a static route returning "ok").

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
RUN apk add --no-cache wget \
 && addgroup -g 10001 -S appgroup \
 && adduser  -u 10001 -S appuser -G appgroup
COPY --from=builder --chown=appuser:appgroup /app/public          ./public
COPY --from=builder --chown=appuser:appgroup /app/.next/standalone ./
COPY --from=builder --chown=appuser:appgroup /app/.next/static     ./.next/static
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/api/health || exit 1
ENTRYPOINT ["node", "server.js"]
