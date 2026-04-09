#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  GITHUB_OWNER
  GITHUB_REPO
  RELEASE_NAME
  GITHUB_PAT
  MODEL_ID
  MODEL_NAME
  MODEL_BASE_URL
)

for v in "${required_vars[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "Missing required environment variable: $v" >&2
    exit 1
  fi
done

# Most OpenAI-compatible local servers expect a key field even if they ignore it.
: "${MODEL_API_KEY:=local-not-required}"
: "${OPENCODE_LOG_LEVEL:=INFO}"
: "${OPENCODE_PRINT_LOGS:=false}"
: "${OPENCODE_HEARTBEAT_SECONDS:=15}"
: "${RELEASE_REPO_DIR:=/tmp/release-repo}"

# Ensure HOME is writable for arbitrary UID (e.g. docker run -u UID:GID)
: "${HOME:=/tmp/home}"
mkdir -p "$HOME"

mkdir -p "${OPENCODE_CONFIG_DIR}" /out

render_template() {
  local input="$1"
  local output="$2"
  local substitutions='${GITHUB_OWNER} ${GITHUB_REPO} ${RELEASE_NAME} ${GITHUB_PAT} ${MODEL_ID} ${MODEL_NAME} ${MODEL_BASE_URL} ${MODEL_API_KEY} ${RELEASE_REPO_DIR}'
  envsubst "$substitutions" < "$input" > "$output"
}

export GITHUB_OWNER GITHUB_REPO RELEASE_NAME GITHUB_PAT MODEL_ID MODEL_NAME MODEL_BASE_URL MODEL_API_KEY RELEASE_REPO_DIR

render_template /app/templates/opencode.template.json "${OPENCODE_CONFIG_DIR}/opencode.json"
render_template /app/templates/prompt.template.md /tmp/prompt.md

log() {
  printf '[entrypoint] %s\n' "$*" >&2
}

strip_opencode_logs() {
  awk '
    !/^(TRACE|DEBUG|INFO|WARN|ERROR)[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}T/ &&
    !/^Database migration complete\.$/ &&
    !/^ProviderModelNotFoundError:/ &&
    !/^ data: \{$/ &&
    !/^  providerID:/ &&
    !/^  modelID:/ &&
    !/^  suggestions:/ &&
    !/^\},$/ &&
    !/^Error: / &&
    !/^Wrote Markdown artifact to /
  '
}

run_and_capture_stdout() {
  local output_file="$1"
  shift
  local status

  set +e
  "$@" | tee "$output_file"
  status=${PIPESTATUS[0]}
  set -e

  return "$status"
}

run_with_heartbeat() {
  local cmd_pid heartbeat_pid

  "$@" &
  cmd_pid=$!

  (
    while kill -0 "$cmd_pid" 2>/dev/null; do
      sleep "$OPENCODE_HEARTBEAT_SECONDS"
      if kill -0 "$cmd_pid" 2>/dev/null; then
        log "OpenCode run still in progress"
      fi
    done
  ) &
  heartbeat_pid=$!

  wait "$cmd_pid"
  local status=$?
  kill "$heartbeat_pid" 2>/dev/null || true
  wait "$heartbeat_pid" 2>/dev/null || true
  return "$status"
}

log "Rendered OpenCode config to ${OPENCODE_CONFIG_DIR}/opencode.json"
log "Rendered prompt to /tmp/prompt.md"

artifact_tmp="$(mktemp /tmp/opencode-output.XXXXXX)"
run_status=0

if [[ "${OPENCODE_PRINT_LOGS}" == "true" ]]; then
  log "Starting OpenCode run with live logs at level ${OPENCODE_LOG_LEVEL}"
  if run_and_capture_stdout "$artifact_tmp" \
    stdbuf -oL -eL \
    opencode --print-logs --log-level "${OPENCODE_LOG_LEVEL}" run --format default "$(cat /tmp/prompt.md)"; then
    run_status=0
  else
    run_status=$?
  fi
  strip_opencode_logs < "$artifact_tmp" > /out/generated-post.md
else
  log "Starting OpenCode run with quiet progress logging"
  if run_and_capture_stdout "$artifact_tmp" \
    run_with_heartbeat \
    sh -c 'exec opencode run --format default "$1"' sh "$(cat /tmp/prompt.md)"; then
    run_status=0
  else
    run_status=$?
  fi
  cp "$artifact_tmp" /out/generated-post.md
fi

log "Wrote run output to /out/generated-post.md"
rm -f "$artifact_tmp"
exit "$run_status"
