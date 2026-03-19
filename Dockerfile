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

COPY src/opencode.template.json /app/templates/opencode.template.json
COPY src/prompt.template.md /app/templates/prompt.template.md
COPY src/code-change-researcher.md /app/config/agents/code-change-researcher.md
COPY src/docker-entrypoint.sh /app/bin/docker-entrypoint.sh
COPY src/checkout-repo.sh /app/bin/checkout-repo.sh

RUN chmod +x /app/bin/docker-entrypoint.sh /app/bin/checkout-repo.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/app/bin/docker-entrypoint.sh"]
