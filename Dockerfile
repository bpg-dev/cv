FROM ghcr.io/gohugoio/hugo:v0.170.1@sha256:4cc9f383086c0fba180efcf7132cf2f025969c462fedf5fcd2bf921915416797 AS builder

WORKDIR /src

ENV HUGO_BASEURL=""

COPY config.yaml ./
COPY layouts/ ./layouts/
COPY assets/ ./assets/
COPY static/ ./static/
COPY data/ ./data/
COPY content/ ./content/

# Hugo runs as hugo (1000:1000); cache mounts default to root ownership
RUN --mount=type=cache,target=/tmp/hugo_cache,uid=1000,gid=1000 \
	hugo --minify --gc --cacheDir /tmp/hugo_cache

# PDF generation and font optimization stage
FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf AS pdf-generator

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
FROM joseluisq/static-web-server:2@sha256:ccf2d666ffe5f8ef2ec96bc40f07757605998c04b78f7d8fdb98a584dd4f5717 AS sws

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
