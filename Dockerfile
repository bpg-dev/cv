FROM ghcr.io/gohugoio/hugo:v0.154.4@sha256:390aae101e6ff6f116827f86e27c4f8b20996da67294851384fe78eb3035253a AS builder

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

FROM caddy:alpine@sha256:f2b257f20955d6be2229bed86bad24193eeb8c4dc962a4031a6eb42344ffa457

ARG GITHUB_REPOSITORY
LABEL org.opencontainers.image.title="CV Site"
LABEL org.opencontainers.image.description="Personal CV/Resume site built with Hugo and served with Caddy"
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY:-unknown/unknown}"

RUN chmod +x /usr/bin/caddy && \
	chown 65534:65534 /usr/bin/caddy 2>/dev/null || true

COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=builder /src/public /usr/share/caddy

RUN chown -R 65534:65534 /usr/share/caddy /etc/caddy 2>/dev/null || true

EXPOSE 80 443 2019

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
	CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]

