FROM node:24-bookworm-slim

# OpenClaw + Codex CLI in one container
RUN npm install -g openclaw@latest @openai/codex@latest \
  && npm cache clean --force

WORKDIR /app

# Minimal OpenClaw config using Codex CLI backend
COPY openclaw.json /app/openclaw.json
COPY openclaw.apikey.json /app/openclaw.apikey.json

# Persist OpenClaw state and Codex auth/session state
ENV OPENCLAW_STATE_DIR=/data/openclaw
ENV OPENCLAW_CONFIG_PATH=/app/openclaw.json
VOLUME ["/data/openclaw", "/root/.codex"]

EXPOSE 18789

# Gateway health probe (requires valid runtime auth to pass fully)
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD openclaw models status >/dev/null 2>&1 || exit 1

CMD ["openclaw", "gateway", "run", "--port", "18789"]
