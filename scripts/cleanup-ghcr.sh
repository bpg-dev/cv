#!/bin/sh
set -e

# Cleanup script for GHCR images
# Keeps: latest tag, last 10 date-tagged images, and every untagged version
#        referenced (via an OCI index / manifest list) by a kept tagged version
# Removes: old date tags, buildcache tags, unreferenced untagged versions
#
# On GHCR a tag usually points at an image index whose per-platform image
# manifests and attestation manifests are stored as separate *untagged*
# package versions. Deleting those breaks every pull of the tag, so the
# script resolves each kept version's manifest from the registry and protects
# its children. Children of date tags deleted in this run become unreferenced
# and are removed on a later run.
#
# Required env: GITHUB_REPOSITORY (owner/repo), GITHUB_TOKEN, GITHUB_ACTOR
# Set DRY_RUN=1 to test without deleting

PACKAGE_NAME=$(echo "${GITHUB_REPOSITORY}" | sed 's|.*/||')
IMAGE_REPO=$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]')
REGISTRY="ghcr.io"
PACKAGE_TYPE="container"
DRY_RUN="${DRY_RUN:-0}"
ERROR_FILE="${TMPDIR:-/tmp}/ghcr_error_$$.txt"
REFERENCED_FILE="${TMPDIR:-/tmp}/ghcr_referenced_$$.txt"
MANIFEST_ACCEPT="application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json"

cleanup() {
  rm -f "${ERROR_FILE}" "${REFERENCED_FILE}"
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

for tool in jq curl; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Error: ${tool} is not installed"
    exit 1
  fi
done

if [ -z "${GITHUB_TOKEN}" ] || [ -z "${GITHUB_ACTOR}" ]; then
  echo "Error: GITHUB_TOKEN and GITHUB_ACTOR must be set (needed for registry manifest lookups)"
  exit 1
fi

REGISTRY_TOKEN=$(curl -fsS -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" \
  "https://${REGISTRY}/token?scope=repository:${IMAGE_REPO}:pull" | jq -r '.token // empty') || REGISTRY_TOKEN=""
if [ -z "${REGISTRY_TOKEN}" ]; then
  echo "Error: could not obtain a registry bearer token for ${REGISTRY}/${IMAGE_REPO}"
  exit 1
fi

# Print the manifest for a digest or tag; fails if the registry returns non-2xx
fetch_manifest() {
  curl -fsS \
    -H "Authorization: Bearer ${REGISTRY_TOKEN}" \
    -H "Accept: ${MANIFEST_ACCEPT}" \
    "https://${REGISTRY}/v2/${IMAGE_REPO}/manifests/$1"
}

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
LATEST_VERSION_IDS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(any(.tags[]?; . == "latest")) | .id')
# Match date tags: YYYYMMDD or YYYYMMDD-SHA (e.g., "20251124" or "20251124-8363a38")
# Exclude versions that also have "latest" tag
DATE_VERSIONS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(any(.tags[]?; test("^[0-9]{8}(-[a-f0-9]+)?$"))) | select(all(.tags[]?; . != "latest")) | {id: .id, created_at: .created_at, timestamp: (.created_at | fromdateiso8601)}' || echo "")
BUILDCACHE_VERSION_IDS=$(echo "${VERSIONS_ARRAY}" | jq -r '.[] | select(any(.tags[]?; . == "buildcache")) | .id')
UNTAGGED_VERSIONS=$(echo "${VERSIONS_ARRAY}" | jq -c '[.[] | select((.tags // []) | length == 0) | {id, name}]')
UNTAGGED_VERSION_IDS=$(echo "${UNTAGGED_VERSIONS}" | jq -r '.[].id')

LATEST_COUNT=$(echo "${LATEST_VERSION_IDS}" | grep -c . || true)
DATE_COUNT=$(echo "${DATE_VERSIONS}" | jq -s 'length' || echo "0")
BUILDCACHE_COUNT=$(echo "${BUILDCACHE_VERSION_IDS}" | grep -c . || true)
UNTAGGED_COUNT=$(echo "${UNTAGGED_VERSION_IDS}" | grep -c . || true)

echo "Found versions:"
echo "  - latest: ${LATEST_COUNT}"
echo "  - date tags: ${DATE_COUNT}"
echo "  - buildcache: ${BUILDCACHE_COUNT}"
echo "  - untagged: ${UNTAGGED_COUNT}"

DATE_DELETE_COUNT=0
BUILDCACHE_DELETE_COUNT=0
UNTAGGED_DELETE_COUNT=0
UNTAGGED_KEEP_COUNT=0
DELETE_IDS=""

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
    DATE_DELETE_COUNT=$(printf '%s\n' "${DELETE_IDS}" | grep -c . || true)
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
  # Every tagged version that survives this run (latest, kept date tags, any
  # other non-buildcache tag) protects the manifests it references.
  DELETED_IDS_JSON=$(printf '%s\n' "${DELETE_IDS}" "${BUILDCACHE_VERSION_IDS}" | jq -R 'select(length > 0) | tonumber' | jq -s '.')
  KEPT_DIGESTS=$(echo "${VERSIONS_ARRAY}" | jq -r --argjson del "${DELETED_IDS_JSON}" \
    '.[] | select((.tags // []) | length > 0) | select(.id as $id | $del | index($id) | not) | .name')

  echo "Resolving manifests referenced by $(printf '%s\n' "${KEPT_DIGESTS}" | grep -c .) kept tagged version(s)..."
  : > "${REFERENCED_FILE}"
  # Worklist: walk indexes (and nested indexes) collecting child digests
  QUEUE="${KEPT_DIGESTS}"
  while [ -n "${QUEUE}" ]; do
    NEXT=""
    for digest in ${QUEUE}; do
      if ! MANIFEST=$(fetch_manifest "${digest}" 2>"${ERROR_FILE}"); then
        if grep -qx "${digest}" "${REFERENCED_FILE}"; then
          # A child the registry no longer serves; nothing further to protect
          echo "  warning: referenced child ${digest} is not served by the registry"
          continue
        fi
        cat "${ERROR_FILE}"
        echo "Error: failed to fetch manifest ${digest} of a kept version; refusing to delete untagged versions"
        exit 1
      fi
      CHILDREN=$(echo "${MANIFEST}" | jq -r '.manifests[]?.digest')
      for child in ${CHILDREN}; do
        if ! grep -qx "${child}" "${REFERENCED_FILE}"; then
          echo "${child}" >> "${REFERENCED_FILE}"
          NEXT="${NEXT} ${child}"
        fi
      done
    done
    QUEUE="${NEXT}"
  done

  REFERENCED_JSON=$(jq -R 'select(length > 0)' "${REFERENCED_FILE}" | jq -s '.')
  echo "Referenced child manifests: $(echo "${REFERENCED_JSON}" | jq 'length')"

  UNTAGGED_DELETE=$(echo "${UNTAGGED_VERSIONS}" | jq -r --argjson ref "${REFERENCED_JSON}" \
    '.[] | select(.name as $n | $ref | index($n) | not) | "\(.id) \(.name)"')
  UNTAGGED_KEEP=$(echo "${UNTAGGED_VERSIONS}" | jq -r --argjson ref "${REFERENCED_JSON}" \
    '.[] | select(.name as $n | $ref | index($n)) | "\(.id) \(.name)"')
  UNTAGGED_DELETE_COUNT=$(printf '%s\n' "${UNTAGGED_DELETE}" | grep -c . || true)
  UNTAGGED_KEEP_COUNT=$(printf '%s\n' "${UNTAGGED_KEEP}" | grep -c . || true)

  echo "Keeping ${UNTAGGED_KEEP_COUNT} referenced untagged version(s)"
  printf '%s\n' "${UNTAGGED_KEEP}" | while IFS=' ' read -r version_id version_name; do
    [ -n "${version_id}" ] && echo "  keep: ${version_name} (ID: ${version_id})"
  done
  echo "Deleting ${UNTAGGED_DELETE_COUNT} unreferenced untagged version(s)"
  printf '%s\n' "${UNTAGGED_DELETE}" | while IFS=' ' read -r version_id version_name; do
    [ -n "${version_id}" ] && delete_version "${version_id}" "untagged ${version_name}"
  done
fi

TOTAL_DELETE_COUNT=$((DATE_DELETE_COUNT + BUILDCACHE_DELETE_COUNT + UNTAGGED_DELETE_COUNT))

echo ""
echo "=== Cleanup Summary ==="
echo "Versions to keep:"
echo "  - latest: ${LATEST_COUNT}"
echo "  - date tags: $((DATE_COUNT - DATE_DELETE_COUNT))"
echo "  - referenced untagged: ${UNTAGGED_KEEP_COUNT}"
echo ""
echo "Versions to delete:"
echo "  - date tags: ${DATE_DELETE_COUNT}"
echo "  - buildcache: ${BUILDCACHE_DELETE_COUNT}"
echo "  - untagged (unreferenced): ${UNTAGGED_DELETE_COUNT}"
echo "  - Total: ${TOTAL_DELETE_COUNT}"
echo ""
echo "Cleanup complete"

# Write summary to GitHub Actions step summary if available
if [ -n "${GITHUB_STEP_SUMMARY}" ]; then
  {
    echo "## GHCR Cleanup Summary"
    echo ""
    echo "### Versions to Keep"
    echo "- **Latest**: ${LATEST_COUNT}"
    echo "- **Date tags**: $((DATE_COUNT - DATE_DELETE_COUNT))"
    echo "- **Referenced untagged**: ${UNTAGGED_KEEP_COUNT}"
    echo ""
    echo "### Versions to Delete"
    echo "- **Date tags**: ${DATE_DELETE_COUNT}"
    echo "- **Buildcache**: ${BUILDCACHE_DELETE_COUNT}"
    echo "- **Untagged**: ${UNTAGGED_DELETE_COUNT}"
    echo "- **Total**: **${TOTAL_DELETE_COUNT}**"
    echo ""
    if [ "${DRY_RUN}" = "1" ]; then
      echo "> ⚠️ **Dry-run mode**: No versions were actually deleted"
    else
      echo "> ✅ Cleanup completed successfully"
    fi
  } >> "${GITHUB_STEP_SUMMARY}"
fi
