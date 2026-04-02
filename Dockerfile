# Stage 1: Fetch frontmatterkit using ghrelgrab
# NOTE: Using ghrelgrab-snapshot:dev for initial testing; update to a released version once verified.
FROM ghcr.io/unitvectory-labs/ghrelgrab-snapshot:dev AS frontmatterkit-fetcher
WORKDIR /work
RUN ["/ghrelgrab", "--repo", "UnitVectorY-Labs/frontmatterkit", "--latest", "--file", "frontmatterkit-{version}-{os}-{arch}.tar.gz", "--out", "/work", "--name", "frontmatterkit", "--debug"]

# Stage 2: Main image
FROM node:25-bookworm 

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENCODE_CONFIG_DIR=/app/config
ENV HOME=/root

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    gettext-base \
    git \
    jq \
    tini \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai

WORKDIR /app

RUN mkdir -p /app/bin /app/config/agents /app/templates /out

COPY --from=frontmatterkit-fetcher /work/frontmatterkit /usr/local/bin/frontmatterkit

COPY src/opencode.template.json /app/templates/opencode.template.json
COPY src/prompt.template.md /app/templates/prompt.template.md
COPY src/code-change-researcher.md /app/config/agents/code-change-researcher.md
COPY src/docker-entrypoint.sh /app/bin/docker-entrypoint.sh
COPY src/checkout-repo.sh /app/bin/checkout-repo.sh
COPY src/validate-frontmatter.sh /app/bin/validate-frontmatter.sh

RUN chmod +x /app/bin/docker-entrypoint.sh /app/bin/checkout-repo.sh /app/bin/validate-frontmatter.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/app/bin/docker-entrypoint.sh"]
