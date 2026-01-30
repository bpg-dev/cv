FROM ghcr.io/gohugoio/hugo:v0.154.5@sha256:53dc48ef4d550835b0e54b0f6b41e22e5160e27065d0691b220a713218eb059d AS builder

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

# PDF generation stage
FROM alpine:3.21@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c AS pdf-generator

# Chromium for accurate PDF rendering (matches browser output exactly)
RUN apk add --no-cache chromium busybox-extras

WORKDIR /src

COPY --from=builder /src/public ./public
COPY data/data.yaml ./data/
COPY scripts/generate-pdf.sh ./scripts/

RUN chmod +x ./scripts/generate-pdf.sh && \
	./scripts/generate-pdf.sh ./public ./data/data.yaml

# Extract Caddy binary from official image
FROM caddy:2.9-alpine@sha256:f2b257f20955d6be2229bed86bad24193eeb8c4dc962a4031a6eb42344ffa457 AS caddy

# Final minimal image using distroless
FROM gcr.io/distroless/static-debian12:nonroot@sha256:cba10d7abd3e203428e86f5b2d7fd5eb7d8987c387864ae4996cf97191b33764

ARG GITHUB_REPOSITORY
LABEL org.opencontainers.image.title="CV Site"
LABEL org.opencontainers.image.description="Personal CV/Resume site built with Hugo and served with Caddy"
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY:-unknown/unknown}"

COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=pdf-generator /src/public /usr/share/caddy

USER nonroot:nonroot

EXPOSE 80 443 2019

CMD ["/usr/bin/caddy", "run", "--config", "/etc/caddy/Caddyfile"]

