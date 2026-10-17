FROM ghcr.io/gohugoio/hugo:v0.168.0@sha256:1fb8fe7f417abd5802d86747d297728aa48078d763159e7dff6559fe3f8bb8e7 AS builder

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
FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 AS pdf-generator

# Chromium for PDF rendering, Python for font subsetting, libwebp for image conversion
RUN apk add --no-cache chromium busybox-extras py3-pip libwebp-tools && \
	pip install --break-system-packages --quiet fonttools brotli

WORKDIR /src

COPY --from=builder /src/public ./public
COPY --from=builder /src/assets/images/profile.jpg ./assets/
COPY data/data.yaml ./data/
COPY scripts/generate-pdf.sh scripts/subset-fonts.sh ./scripts/

RUN chmod +x ./scripts/generate-pdf.sh ./scripts/subset-fonts.sh && \
	cwebp -q 85 ./assets/profile.jpg -o ./public/profile.webp && \
	./scripts/generate-pdf.sh ./public ./data/data.yaml && \
	./scripts/subset-fonts.sh ./public/assets/fontawesome

# Get static-web-server binary
FROM joseluisq/static-web-server:2@sha256:94618e3d17802265a21926217e6f9e7832b311b6fbf5933684001739fafed06a AS sws

# Final minimal image using distroless static (smaller, no glibc needed)
FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab

ARG GITHUB_REPOSITORY
LABEL org.opencontainers.image.title="CV Site"
LABEL org.opencontainers.image.description="Personal CV/Resume site built with Hugo and served with static-web-server"
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY:-unknown/unknown}"

COPY --from=sws /static-web-server /static-web-server
COPY static-web-server.toml /config.toml
COPY --from=pdf-generator /src/public /public

USER nonroot:nonroot

EXPOSE 8080

CMD ["/static-web-server", "--config-file", "/config.toml"]
