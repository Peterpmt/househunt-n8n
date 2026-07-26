# ============================================================
# HOUSEHUNT - Custom n8n Docker Image for Render Web Service
# ============================================================

FROM n8nio/n8n:latest

# Switch to root to install global packages
USER root

# Install the FREE AI Community Node (Panda Free LLM)
RUN npm install -g n8n-nodes-panda-free-llm

# Switch back to the secure n8n user
USER node

# ============================================================
# ENVIRONMENT VARIABLES (Override in Render Dashboard)
# ============================================================

ENV N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
ENV N8N_COMMUNITY_PACKAGES=n8n-nodes-panda-free-llm
ENV N8N_SECURE_COOKIE=false
ENV N8N_USER_FOLDER=/home/node/.n8n

# Expose the port
EXPOSE 5678

# Healthcheck (curl is already available in the base image)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5678/healthz || exit 1

# NO CMD override – the base image's default (ENTRYPOINT tini -- n8n, CMD start) will be used.
