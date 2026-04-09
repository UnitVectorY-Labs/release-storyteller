#!/usr/bin/env bash
set -euo pipefail

dest="${1:-${RELEASE_REPO_DIR:-/tmp/release-repo}}"

if [[ -z "${GITHUB_OWNER:-}" || -z "${GITHUB_REPO:-}" || -z "${GITHUB_PAT:-}" ]]; then
  echo "GITHUB_OWNER, GITHUB_REPO, and GITHUB_PAT must be set" >&2
  exit 1
fi

mkdir -p "$(dirname "${dest}")"

repo_url="https://x-access-token:${GITHUB_PAT}@github.com/${GITHUB_OWNER}/${GITHUB_REPO}.git"
public_url="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}.git"

if [[ -d "${dest}/.git" ]]; then
  git -C "${dest}" remote set-url origin "${repo_url}"
  git -C "${dest}" fetch --force --tags origin
else
  rm -rf "${dest}"
  git clone "${repo_url}" "${dest}"
fi

git -C "${dest}" remote set-url origin "${public_url}"
echo "${dest}"
