#!/bin/sh
set -e

PUBLIC_DIR="${1:-/src/public}"
DATA_FILE="${2:-/src/data/data.yaml}"
PORT=8765

# Convert to absolute paths
PUBLIC_DIR=$(cd "$PUBLIC_DIR" && pwd)
DATA_FILE=$(cd "$(dirname "$DATA_FILE")" && pwd)/$(basename "$DATA_FILE")

# Extract name from data.yaml and remove spaces
NAME=$(grep -A1 '^basic:' "$DATA_FILE" | grep 'name:' | sed 's/.*name: *\([^#]*\).*/\1/' | tr -d ' \n')

# Get current date in YYYYMMDD format
DATE=$(date +%Y%m%d)

# Generate filename
OUTPUT_FILE="${PUBLIC_DIR}/${NAME}-${DATE}.pdf"

echo "Generating PDF: ${OUTPUT_FILE}..."

# Start busybox httpd in foreground, but backgrounded so we can kill it
httpd -f -p "$PORT" -h "$PUBLIC_DIR" &
HTTPD_PID=$!

# Ensure httpd is killed on exit
trap "kill $HTTPD_PID 2>/dev/null" EXIT

# Give server a moment to start
sleep 1

# Use Chromium headless to generate PDF (renders exactly like browser)
# --virtual-time-budget gives time for web fonts (FontAwesome) to load
timeout 30 chromium-browser \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-software-rasterizer \
    --no-pdf-header-footer \
    --virtual-time-budget=5000 \
    --print-to-pdf="$OUTPUT_FILE" \
    "http://127.0.0.1:${PORT}/"

# Kill httpd
kill $HTTPD_PID 2>/dev/null || true

echo "PDF generated: ${OUTPUT_FILE}"
