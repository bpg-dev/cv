#!/bin/sh
set -e

# FontAwesome icon subsets - only icons actually used on the site
# Run: curl -s http://localhost:8080/ | grep -oE 'fa-[a-z-]+' | sort -u
# to find all icons used on the site

ASSETS_DIR="${1:-./public/assets/fontawesome}"

# Install fonttools if not present
if ! command -v pyftsubset >/dev/null 2>&1; then
    pip install --quiet fonttools brotli
fi

echo "Subsetting FontAwesome fonts..."

# Solid icons Unicode codepoints
# briefcase=f0b1, certificate=f0a3, earth-americas=f57d, envelope=f0e0,
# file-pdf=f1c1, folder-open=f07c, graduation-cap=f19d, hand-spock=f259,
# link=f0c1, location-dot=f3c5, toolbox=f552, user=f007, user-graduate=f501
SOLID_UNICODES="U+f0b1,U+f0a3,U+f57d,U+f0e0,U+f1c1,U+f07c,U+f19d,U+f259,U+f0c1,U+f3c5,U+f552,U+f007,U+f501"

# Brand icons Unicode codepoints
# github=f09b, linkedin=f08c, mastodon=f4f6, strava=f428
BRAND_UNICODES="U+f09b,U+f08c,U+f4f6,U+f428"

# Subset solid font
if [ -f "$ASSETS_DIR/webfonts/fa-solid-900.woff2" ]; then
    pyftsubset "$ASSETS_DIR/webfonts/fa-solid-900.woff2" \
        --unicodes="$SOLID_UNICODES" \
        --flavor=woff2 \
        --output-file="$ASSETS_DIR/webfonts/fa-solid-900.subset.woff2"
    mv "$ASSETS_DIR/webfonts/fa-solid-900.subset.woff2" "$ASSETS_DIR/webfonts/fa-solid-900.woff2"
    echo "  Solid font subset created"
fi

# Subset brands font
if [ -f "$ASSETS_DIR/webfonts/fa-brands-400.woff2" ]; then
    pyftsubset "$ASSETS_DIR/webfonts/fa-brands-400.woff2" \
        --unicodes="$BRAND_UNICODES" \
        --flavor=woff2 \
        --output-file="$ASSETS_DIR/webfonts/fa-brands-400.subset.woff2"
    mv "$ASSETS_DIR/webfonts/fa-brands-400.subset.woff2" "$ASSETS_DIR/webfonts/fa-brands-400.woff2"
    echo "  Brands font subset created"
fi

# Remove unused font files
rm -f "$ASSETS_DIR/webfonts/fa-regular-400.woff2"
rm -f "$ASSETS_DIR/webfonts/fa-v4compatibility.woff2"

echo "Font subsetting complete"
