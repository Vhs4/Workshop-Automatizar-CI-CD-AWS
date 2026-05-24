# syntax=docker/dockerfile:1.7
# Multi-stage build for YoutubeLiveApp (ASP.NET Core 8 Web API).
# Final image: Alpine-based ASP.NET runtime, non-root user (UID 10001),
# listens on :8080, HEALTHCHECK hits /backend/health.

FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src
COPY YoutubeLiveApp.csproj ./
RUN dotnet restore YoutubeLiveApp.csproj
COPY . .
RUN dotnet publish YoutubeLiveApp.csproj \
        -c Release \
        -o /app/publish \
        --no-restore \
        /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_EnableDiagnostics=0
RUN apk add --no-cache wget \
 && addgroup -g 10001 -S appgroup \
 && adduser  -u 10001 -S appuser -G appgroup
COPY --from=build --chown=appuser:appgroup /app/publish ./
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/backend/health || exit 1
ENTRYPOINT ["dotnet", "YoutubeLiveApp.dll"]
