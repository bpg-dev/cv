#!/bin/sh
set -e

# FontAwesome icon subsets - only icons actually used on the site
# Solid icons: briefcase, envelope, file-pdf, graduation-cap, link, location-dot, user-graduate
# Brand icons: github, linkedin, mastodon, strava

ASSETS_DIR="${1:-./public/assets/fontawesome}"

# Install fonttools if not present
if ! command -v pyftsubset >/dev/null 2>&1; then
    pip install --quiet fonttools brotli
fi

echo "Subsetting FontAwesome fonts..."

# Solid icons Unicode codepoints
# briefcase=f0b1, envelope=f0e0, file-pdf=f1c1, graduation-cap=f19d, link=f0c1, location-dot=f3c5, user-graduate=f501
SOLID_UNICODES="U+f0b1,U+f0e0,U+f1c1,U+f19d,U+f0c1,U+f3c5,U+f501"

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
