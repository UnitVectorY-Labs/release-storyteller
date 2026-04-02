#!/usr/bin/env bash
set -euo pipefail

ARTICLE="${1:-/out/article.md}"

if [[ ! -f "$ARTICLE" ]]; then
  echo "Error: Article file not found: $ARTICLE" >&2
  exit 1
fi

# Convert a string to a tag-safe value: lowercase, non-alphanumeric replaced
# with hyphens, collapsed, and trimmed.
make_tag_safe() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9-]/-/g' \
    | sed 's/--*/-/g' \
    | sed 's/^-//;s/-$//'
}

REPO_TAG=$(make_tag_safe "${GITHUB_REPO}")
MODEL_TAG=$(make_tag_safe "${MODEL_NAME}")

echo "Setting tags: [${REPO_TAG}, ${MODEL_TAG}]"

# Set the tags programmatically using frontmatterkit
frontmatterkit set \
  --set ".tags=[\"${REPO_TAG}\", \"${MODEL_TAG}\"]" \
  --mode patch \
  --in "$ARTICLE" \
  --in-place

# Validate front matter YAML
echo "Validating front matter..."
frontmatterkit validate --in "$ARTICLE"

# Assert required fields
echo "Asserting required fields..."
frontmatterkit assert \
  --assert '.layout == "post"' \
  --assert '.title exists' \
  --assert '.date exists' \
  --assert '.tags exists' \
  --in "$ARTICLE"

echo "Front matter validation passed successfully."
