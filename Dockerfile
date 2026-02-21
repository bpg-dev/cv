FROM ghcr.io/gohugoio/hugo:v0.155.2@sha256:5315e95d73a13bd7f89127f7fc39de71be84e12fa8c296a20e90394c85422b0b AS builder

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
FROM alpine:3.23@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS pdf-generator

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
FROM joseluisq/static-web-server:2@sha256:34bb160fd62d2145dabd0598f36352653ec58cf80a8d58c8cd2617097d34564d AS sws

# Final minimal image using distroless static (smaller, no glibc needed)
FROM gcr.io/distroless/static-debian12:nonroot@sha256:cba10d7abd3e203428e86f5b2d7fd5eb7d8987c387864ae4996cf97191b33764

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
