FROM node:22.22.3-bookworm-slim

# git and gh are required by Factory's sandbox (clone, push, open PRs); the rest are
# what coding agents reach for when they run a repo's checks in the local sandbox.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git gnupg openssh-client ripgrep python3 make g++ \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/* \
 && corepack enable

# Upstream template, pinned. Bump UPSTREAM_REF and the image tag together.
ARG UPSTREAM_REF=ebde794a8656278cf26bbb2b8764be7070b325d9
WORKDIR /app
RUN curl -fsSL https://codeload.github.com/mastra-ai/softwarefactory-template/tar.gz/${UPSTREAM_REF} | tar xz --strip-components=1

COPY workos-access.ts src/mastra/workos-access.ts
COPY patch-entry.mjs /tmp/patch-entry.mjs
RUN node /tmp/patch-entry.mjs && npm install --no-audit --no-fund && npm run build && npm cache clean --force

ENV NODE_ENV=production PORT=4111 MASTRA_HOST=:: MASTRA_APP_DATA_DIR=/data/app MASTRACODE_LOCAL_SANDBOX_ROOT=/data/sandboxes HOME=/data/home
EXPOSE 4111
WORKDIR /app/.mastra/output
CMD ["/bin/sh", "-c", "mkdir -p /data/app /data/sandboxes /data/home && exec node index.mjs"]
