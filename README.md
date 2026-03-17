# release-storyteller

`release-storyteller` is a small Dockerized workflow that researches a GitHub release and generates a user-facing Markdown announcement post.

It uses OpenCode to:
- inspect release metadata and repository context
- delegate code-change analysis to a dedicated subagent
- write release artifacts into `/out`

## Build

```bash
docker build -t release-storyteller:latest .
```

## Usage

Required environment variables:
- `GITHUB_OWNER`
- `GITHUB_REPO`
- `RELEASE_NAME`
- `GITHUB_PAT`
- `MODEL_ID`
- `MODEL_NAME`
- `MODEL_BASE_URL`

Optional environment variables:
- `MODEL_API_KEY` defaults to `local-not-required`
- `OPENCODE_LOG_LEVEL` defaults to `INFO`
- `OPENCODE_PRINT_LOGS` defaults to `false`
- `OPENCODE_HEARTBEAT_SECONDS` defaults to `15`

Example:

```bash
docker run --rm \
  -e GITHUB_OWNER="example-org" \
  -e GITHUB_REPO="example-repo" \
  -e RELEASE_NAME="v1.2.3" \
  -e GITHUB_PAT="ghp_your_token" \
  -e MODEL_ID="your-model-name" \
  -e MODEL_NAME="Your Model Display Name" \
  -e MODEL_BASE_URL="https://llm.example.com/v1" \
  -e MODEL_API_KEY="your-api-key" \
  -v "$(pwd)/out:/out" \
  release-storyteller:latest
```

## Output

The container writes these artifacts to the mounted `/out` directory:
- `article.md`: final release announcement
- `release-research.md`: research notes collected for the release
- `generated-post.md`: captured stdout from the OpenCode run
