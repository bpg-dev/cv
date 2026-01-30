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

# PDF generation and font optimization stage
FROM alpine:3.21@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c AS pdf-generator

# Chromium for PDF rendering, Python for font subsetting
RUN apk add --no-cache chromium busybox-extras py3-pip && \
	pip install --break-system-packages --quiet fonttools brotli

WORKDIR /src

COPY --from=builder /src/public ./public
COPY data/data.yaml ./data/
COPY scripts/generate-pdf.sh scripts/subset-fonts.sh ./scripts/

RUN chmod +x ./scripts/generate-pdf.sh ./scripts/subset-fonts.sh && \
	./scripts/generate-pdf.sh ./public ./data/data.yaml && \
	./scripts/subset-fonts.sh ./public/assets/fontawesome

# Extract and prepare Caddy binary (strip file capabilities for cap-drop=ALL compatibility)
FROM caddy:2@sha256:70e816c44fb79071fc4cd939ffda76e3b629642309efe31a4fb0ed45873be464 AS caddy
RUN setcap -r /usr/bin/caddy

# Final minimal image using distroless with glibc
FROM gcr.io/distroless/base-debian12:nonroot@sha256:107333192f6732e786f65df4df77f1d8bfb500289aad09540e43e0f7b6a2b816

ARG GITHUB_REPOSITORY
LABEL org.opencontainers.image.title="CV Site"
LABEL org.opencontainers.image.description="Personal CV/Resume site built with Hugo and served with Caddy"
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY:-unknown/unknown}"

COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=pdf-generator /src/public /usr/share/caddy

USER nonroot:nonroot

EXPOSE 8080 2019

CMD ["/usr/bin/caddy", "run", "--config", "/etc/caddy/Caddyfile"]

