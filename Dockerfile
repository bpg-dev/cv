FROM ghcr.io/gohugoio/hugo:v0.161.1@sha256:cef5b132b220dd5a661787d410124afe807b0ed3a79829604bdf0c3eefb85488 AS builder

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
FROM alpine:3.23@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS pdf-generator

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
FROM joseluisq/static-web-server:2@sha256:2d67e47e22172235e339908777e692006ffdcf42dc4c531aff5d4337a7559a1e AS sws

# Final minimal image using distroless static (smaller, no glibc needed)
FROM gcr.io/distroless/static-debian12:nonroot@sha256:d093aa3e30dbadd3efe1310db061a14da60299baff8450a17fe0ccc514a16639

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
