# Multi-stage build for Hugo static site
# Stage 1: Build the site with Hugo
# Pinned Hugo version for reproducible builds
# Using official Hugo image from GitHub Container Registry
# Hugo v0.152.2 (latest, supports css.Sass function)
# Digest pinned for reproducibility (linux/amd64)
FROM ghcr.io/gohugoio/hugo:v0.152.2@sha256:d2952bdcfa3b0b25ca3d2104394c2883ffa86abb88855515f01b23b5e8f1355b AS builder

# Set working directory
WORKDIR /src

# Copy Hugo configuration and content
COPY config.yaml ./
COPY content/ ./content/
COPY data/ ./data/
COPY layouts/ ./layouts/
COPY assets/ ./assets/
COPY static/ ./static/

# Build the site
# Set baseURL to empty for container builds (can be overridden via env)
ENV HUGO_BASEURL=""
RUN hugo --minify --gc

# Stage 2: Serve with Caddy
# Pinned Caddy version for reproducible builds
# Caddy v2.10.2 (from caddy:alpine tag)
FROM caddy:alpine@sha256:953131cfea8e12bfe1c631a36308e9660e4389f0c3dfb3be957044d3ac92d446

# Copy built site from builder stage
COPY --from=builder /src/public /usr/share/caddy

# Copy Caddyfile configuration
COPY Caddyfile /etc/caddy/Caddyfile

# Expose ports 80 (HTTP) and 443 (HTTPS)
EXPOSE 80
EXPOSE 443

# Health check
# Note: Kubernetes will handle health checks via liveness/readiness probes
# This is included for local Docker usage
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Caddy runs as non-root user by default
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]

