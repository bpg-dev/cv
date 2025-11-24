#!/bin/sh
set -e

# Cleanup script for GHCR images
# Keeps: latest tag, at least one date tag, last 10 date-tagged images
# Removes: old date tags, buildcache tags, all untagged versions
# Set DRY_RUN=1 to test without deleting

PACKAGE_NAME=$(echo "${GITHUB_REPOSITORY}" | sed 's|.*/||')
PACKAGE_TYPE="container"
DRY_RUN="${DRY_RUN:-0}"
ERROR_FILE="${TMPDIR:-/tmp}/ghcr_error_$$.txt"

cleanup() {
  rm -f "${ERROR_FILE}"
}
trap cleanup EXIT

if [ "${DRY_RUN}" = "1" ]; then
  echo "=== DRY RUN MODE - No deletions will be performed ==="
fi

echo "Starting cleanup for ghcr.io/${PACKAGE_NAME}"

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is not installed"
  exit 1
fi

if [ -z "${GITHUB_TOKEN}" ] && ! gh auth status >/dev/null 2>&1; then
  echo "Error: GITHUB_TOKEN is not set and no existing GitHub CLI authentication found"
  exit 1
fi

delete_version() {
  version_id=$1
  version_name=$2
  if [ "${DRY_RUN}" = "1" ]; then
    echo "[DRY RUN] Would delete version: ${version_name} (ID: ${version_id})"
  else
    echo "Deleting version: ${version_name} (ID: ${version_id})"
    gh api -X DELETE "/user/packages/${PACKAGE_TYPE}/${PACKAGE_NAME}/versions/${version_id}" --jq . || true
  fi
}

echo "Fetching package versions..."
VERSIONS_JSON=$(gh api \
  "/user/packages/${PACKAGE_TYPE}/${PACKAGE_NAME}/versions" \
  --paginate \
  --jq '.[] | {id: .id, name: .name, created_at: .created_at, tags: .metadata.container.tags}' 2>"${ERROR_FILE}") || API_EXIT_CODE=$?

if [ -s "${ERROR_FILE}" ]; then
  ERROR_MSG=$(cat "${ERROR_FILE}")
  if echo "${ERROR_MSG}" | grep -qE '"status":\s*404|"message":\s*"Not Found"|"message":\s*"Package not found"'; then
    echo "No package versions found (package does not exist yet)"
    exit 0
  fi
  if echo "${ERROR_MSG}" | grep -qE '"status":\s*403|"message":\s*"Forbidden"'; then
    echo "Error: Permission denied. Make sure GITHUB_TOKEN has 'packages:read' and 'packages:write' permissions."
    exit 1
  fi
  echo "Error fetching package versions: ${ERROR_MSG}"
  exit 1
fi

if [ "${API_EXIT_CODE:-0}" -ne 0 ] || [ -z "${VERSIONS_JSON}" ]; then
  echo "No package versions found"
  exit 0
fi

echo "Processing versions..."

VERSIONS_ARRAY=$(echo "${VERSIONS_JSON}" | jq -s '.' || echo "[]")
LATEST_VERSION_IDS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(.tags[]? == "latest") | .id')
# Match date tags: YYYYMMDD or YYYYMMDD-SHA (e.g., "20251124" or "20251124-8363a38")
# Exclude versions that also have "latest" tag
DATE_VERSIONS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(.tags[]? | test("^[0-9]{8}(-[a-f0-9]+)?$")) | select(.tags[]? != "latest") | {id: .id, created_at: .created_at, timestamp: (.created_at | fromdateiso8601)}' || echo "")
BUILDCACHE_VERSION_IDS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(.tags[]? == "buildcache") | .id')
UNTAGGED_VERSION_IDS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(.tags | length == 0) | .id')

LATEST_COUNT=$(echo "${LATEST_VERSION_IDS}" | grep -c . 2>/dev/null || echo "0")
DATE_COUNT=$(echo "${DATE_VERSIONS}" | jq -s 'length' || echo "0")
BUILDCACHE_COUNT=$(echo "${BUILDCACHE_VERSION_IDS}" | grep -c . 2>/dev/null || echo "0")
UNTAGGED_COUNT=$(echo "${UNTAGGED_VERSION_IDS}" | grep -c . 2>/dev/null || echo "0")

echo "Found versions:"
echo "  - latest: ${LATEST_COUNT}"
echo "  - date tags: ${DATE_COUNT}"
echo "  - buildcache: ${BUILDCACHE_COUNT}"
echo "  - untagged: ${UNTAGGED_COUNT}"

DATE_DELETE_COUNT=0
BUILDCACHE_DELETE_COUNT=0
UNTAGGED_DELETE_COUNT=0

if [ "${LATEST_COUNT}" -gt 0 ]; then
  echo "Keeping all 'latest' tag versions"
fi

if [ "${DATE_COUNT}" -gt 0 ]; then
  DATE_VERSIONS_SORTED=$(echo "${DATE_VERSIONS}" | jq -s 'sort_by(-.timestamp)' || echo "[]")
  KEEP_COUNT=$((DATE_COUNT > 10 ? 10 : DATE_COUNT))
  
  VERSIONS_TO_DELETE=$(echo "${DATE_VERSIONS_SORTED}" | jq ".[${KEEP_COUNT}:]")
  DELETE_IDS=$(echo "${VERSIONS_TO_DELETE}" | jq -r '.[] | .id')
  
  if [ -z "${DELETE_IDS}" ]; then
    DATE_DELETE_COUNT=0
  else
    DATE_DELETE_COUNT=$(printf '%s\n' "${DELETE_IDS}" | grep -c . 2>/dev/null || echo "0")
  fi
  
  echo "Keeping ${KEEP_COUNT} date tag version(s)"
  echo "Will delete ${DATE_DELETE_COUNT} old date tag version(s)"
  
  if [ "${DATE_DELETE_COUNT}" -gt 0 ]; then
    echo "${DELETE_IDS}" | while IFS= read -r version_id; do
      [ -n "${version_id}" ] && [ "${version_id}" != "null" ] && delete_version "${version_id}" "date-tagged"
    done
  fi
fi

if [ "${BUILDCACHE_COUNT}" -gt 0 ]; then
  BUILDCACHE_DELETE_COUNT="${BUILDCACHE_COUNT}"
  echo "Deleting ${BUILDCACHE_DELETE_COUNT} buildcache tag version(s)"
  echo "${BUILDCACHE_VERSION_IDS}" | while IFS= read -r version_id; do
    [ -n "${version_id}" ] && [ "${version_id}" != "null" ] && delete_version "${version_id}" "buildcache"
  done
fi

if [ "${UNTAGGED_COUNT}" -gt 0 ]; then
  UNTAGGED_DELETE_COUNT="${UNTAGGED_COUNT}"
  echo "Deleting ${UNTAGGED_DELETE_COUNT} untagged version(s)"
  echo "${UNTAGGED_VERSION_IDS}" | while IFS= read -r version_id; do
    [ -n "${version_id}" ] && [ "${version_id}" != "null" ] && delete_version "${version_id}" "untagged"
  done
fi

TOTAL_DELETE_COUNT=$((DATE_DELETE_COUNT + BUILDCACHE_DELETE_COUNT + UNTAGGED_DELETE_COUNT))

echo ""
echo "=== Cleanup Summary ==="
echo "Versions to keep:"
echo "  - latest: ${LATEST_COUNT}"
echo "  - date tags: $((DATE_COUNT - DATE_DELETE_COUNT))"
echo ""
echo "Versions to delete:"
echo "  - date tags: ${DATE_DELETE_COUNT}"
echo "  - buildcache: ${BUILDCACHE_DELETE_COUNT}"
echo "  - untagged: ${UNTAGGED_DELETE_COUNT}"
echo "  - Total: ${TOTAL_DELETE_COUNT}"
echo ""
echo "Cleanup complete"
