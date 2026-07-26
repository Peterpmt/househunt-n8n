# ============================================================
# HOUSEHUNT - Custom n8n Docker Image for Render Web Service
# ============================================================

FROM n8nio/n8n:latest

# Switch to root to install global packages
USER root

# Install the FREE AI Community Node (Panda Free LLM)
# This gives you Groq, Gemini, OpenRouter, and Mistral for $0
RUN npm install -g n8n-nodes-panda-free-llm

# Clean up to keep image size small
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch back to the secure n8n user
USER node

# ============================================================
# ENVIRONMENT DEFAULTS (Overridden by Render Dashboard)
# ============================================================

# Tell n8n to load the community node we just installed
ENV N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
ENV N8N_COMMUNITY_PACKAGES=n8n-nodes-panda-free-llm

# Basic n8n settings (Database variables will be set in Render UI)
ENV N8N_SECURE_COOKIE=false
ENV N8N_USER_FOLDER=/home/node/.n8n

# Expose the default n8n port
EXPOSE 5678

# Healthcheck so Render knows your service is alive
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5678/healthz || exit 1

# n8n default start command
CMD ["n8n", "start"]
