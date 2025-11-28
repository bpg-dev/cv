FROM ghcr.io/gohugoio/hugo:v0.152.2@sha256:d2952bdcfa3b0b25ca3d2104394c2883ffa86abb88855515f01b23b5e8f1355b AS builder

WORKDIR /src

ENV HUGO_BASEURL=""

COPY config.yaml ./
COPY layouts/ ./layouts/
COPY assets/ ./assets/
COPY static/ ./static/
COPY data/ ./data/
COPY content/ ./content/

RUN --mount=type=cache,target=/tmp/hugo_cache \
  hugo --minify --gc --cacheDir /tmp/hugo_cache

FROM caddy:alpine@sha256:953131cfea8e12bfe1c631a36308e9660e4389f0c3dfb3be957044d3ac92d446

ARG GITHUB_REPOSITORY
LABEL org.opencontainers.image.title="CV Site"
LABEL org.opencontainers.image.description="Personal CV/Resume site built with Hugo and served with Caddy"
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY:-unknown/unknown}"

# Use UID 65534 (nobody) which exists in the base Alpine image
# This matches the pattern used by other workloads in the cluster (e.g., echo)
# Ensure Caddy binary is executable and owned by nobody for Kubernetes compatibility
RUN chmod +x /usr/bin/caddy && \
    chown 65534:65534 /usr/bin/caddy 2>/dev/null || true

COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=builder /src/public /usr/share/caddy

# Set ownership to nobody (65534) for compatibility with Kubernetes security contexts
# The nobody user already exists in Alpine, so we don't need to create it
RUN chown -R 65534:65534 /usr/share/caddy /etc/caddy 2>/dev/null || true

EXPOSE 80 443 2019

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Don't set USER here - let Kubernetes securityContext handle it
# This allows the image to work with different security contexts
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]

