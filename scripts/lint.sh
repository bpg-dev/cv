#!/bin/sh
set -e

echo "Running linters..."

if command -v hadolint >/dev/null 2>&1; then
  echo "Running hadolint..."
  hadolint Dockerfile
else
  echo "hadolint not installed, skipping"
fi

if command -v checkmake >/dev/null 2>&1; then
  echo "Running checkmake..."
  checkmake --config .checkmake.ini Makefile || true
else
  echo "checkmake not installed, skipping"
fi

if command -v actionlint >/dev/null 2>&1; then
  echo "Running actionlint..."
  actionlint .github/workflows/*.yml
else
  echo "actionlint not installed, skipping"
fi

if command -v yamllint >/dev/null 2>&1; then
  echo "Running yamllint..."
  yamllint .github/workflows/*.yml config.yaml renovate.json
  yamllint -d .yamllint-data.yml data/*.yaml
else
  echo "yamllint not installed, skipping"
fi

echo "Linting complete"

