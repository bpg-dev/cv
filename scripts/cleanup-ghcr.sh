#!/bin/sh
set -e

# Cleanup script for GHCR images
# Keeps: latest tag, at least one date tag, last 10 date-tagged images
# Removes: old date tags, buildcache tags
# Set DRY_RUN=1 to test without deleting

PACKAGE_NAME="${GITHUB_REPOSITORY}"
PACKAGE_TYPE="container"
DRY_RUN="${DRY_RUN:-0}"

if [ "${DRY_RUN}" = "1" ]; then
  echo "=== DRY RUN MODE - No deletions will be performed ==="
fi

echo "Starting cleanup for ghcr.io/${PACKAGE_NAME}"

# Check if gh CLI is available
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is not installed"
  exit 1
fi

# Authenticate with GitHub
if [ -z "${GITHUB_TOKEN}" ]; then
  echo "Error: GITHUB_TOKEN is not set"
  exit 1
fi

echo "${GITHUB_TOKEN}" | gh auth login --with-token

# Function to delete a package version
delete_version() {
  version_id=$1
  version_name=$2
  if [ "${DRY_RUN}" = "1" ]; then
    echo "[DRY RUN] Would delete version: ${version_name} (ID: ${version_id})"
  else
    echo "Deleting version: ${version_name} (ID: ${version_id})"
    gh api \
      -X DELETE \
      "/user/packages/${PACKAGE_TYPE}/${PACKAGE_NAME}/versions/${version_id}" \
      --jq . || true
  fi
}

# Get all package versions
echo "Fetching package versions..."
VERSIONS_JSON=$(gh api \
  "/user/packages/${PACKAGE_TYPE}/${PACKAGE_NAME}/versions" \
  --paginate \
  --jq '.[] | {id: .id, name: .name, created_at: .created_at, tags: .metadata.container.tags}')

if [ -z "${VERSIONS_JSON}" ]; then
  echo "No package versions found"
  exit 0
fi

# Process versions and categorize them
echo "Processing versions..."

# Convert to array and process
VERSIONS_ARRAY=$(echo "${VERSIONS_JSON}" | jq -s '.')

# Find versions with latest tag (always keep these)
LATEST_VERSION_IDS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(.tags[]? == "latest") | .id')

# Find versions with date tags (YYYYMMDD format), but exclude those with "latest" tag
DATE_VERSIONS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(.tags[]? | test("^[0-9]{8}$")) | select(.tags[]? != "latest") | {id: .id, created_at: .created_at, timestamp: (.created_at | fromdateiso8601)}')

# Find versions with buildcache tag
BUILDCACHE_VERSION_IDS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(.tags[]? == "buildcache") | .id')

# Count versions
LATEST_COUNT=$(echo "${LATEST_VERSION_IDS}" | grep -c . || echo "0")
DATE_COUNT=$(echo "${DATE_VERSIONS}" | jq -s 'length')
BUILDCACHE_COUNT=$(echo "${BUILDCACHE_VERSION_IDS}" | grep -c . || echo "0")

echo "Found versions:"
echo "  - latest: ${LATEST_COUNT}"
echo "  - date tags: ${DATE_COUNT}"
echo "  - buildcache: ${BUILDCACHE_COUNT}"

# Always keep latest tag versions
if [ "${LATEST_COUNT}" -gt 0 ]; then
  echo "Keeping all 'latest' tag versions"
fi

# For date tags: keep at least one, and keep the last 10
if [ "${DATE_COUNT}" -gt 0 ]; then
  # Sort by timestamp (newest first)
  DATE_VERSIONS_SORTED=$(echo "${DATE_VERSIONS}" | jq -s 'sort_by(-.timestamp)')
  
  # Keep at least 1, but up to 10
  KEEP_COUNT=$((DATE_COUNT > 10 ? 10 : DATE_COUNT))
  KEEP_COUNT=$((KEEP_COUNT < 1 ? 1 : KEEP_COUNT))
  
  VERSIONS_TO_DELETE=$(echo "${DATE_VERSIONS_SORTED}" | jq ".[${KEEP_COUNT}:]")
  
  DELETE_IDS=$(echo "${VERSIONS_TO_DELETE}" | jq -r '.[] | .id')
  
  echo "Keeping ${KEEP_COUNT} date tag version(s)"
  DELETE_COUNT=$(echo "${DELETE_IDS}" | grep -c . || echo "0")
  echo "Will delete ${DELETE_COUNT} old date tag version(s)"
  
  # Delete old date tag versions
  if [ "${DELETE_COUNT}" -gt 0 ]; then
    echo "${DELETE_IDS}" | while IFS= read -r version_id; do
      if [ -n "${version_id}" ] && [ "${version_id}" != "null" ]; then
        delete_version "${version_id}" "date-tagged"
      fi
    done
  fi
fi

# Delete all buildcache tags
if [ "${BUILDCACHE_COUNT}" -gt 0 ]; then
  echo "Deleting ${BUILDCACHE_COUNT} buildcache tag version(s)"
  echo "${BUILDCACHE_VERSION_IDS}" | while IFS= read -r version_id; do
    if [ -n "${version_id}" ] && [ "${version_id}" != "null" ]; then
      delete_version "${version_id}" "buildcache"
    fi
  done
fi

echo "Cleanup complete"
