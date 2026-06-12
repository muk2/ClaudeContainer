FROM docker/sandbox-templates:claude-code

USER root

# ── System deps ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ make cmake \
    pkg-config libssl-dev libffi-dev zlib1g-dev \
    python3 python3-dev \
    curl wget unzip htop tree strace \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 22 LTS via NodeSource ───────────────────────
# Base image has Node but we ensure latest LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# ── Bun ──────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash && \
    cp /root/.bun/bin/bun /usr/local/bin/bun && \
    cp /root/.bun/bin/bunx /usr/local/bin/bunx

# ── pnpm ─────────────────────────────────────────────────
RUN npm install -g pnpm

# ── Global dev tools ────────────────────────────────────
RUN npm install -g \
    typescript \
    tsx \
    ts-node \
    @types/node \
    eslint \
    prettier \
    vitest \
    jest \
    nodemon \
    concurrently \
    turbo \
    wrangler \
    vercel \
    @biomejs/biome

# ── Framework CLIs ──────────────────────────────────────
RUN npm install -g \
    next \
    create-next-app \
    @nestjs/cli \
    prisma \
    drizzle-kit \
    @anthropic-ai/sdk \
    openai

# ── Ensure agent user has access ────────────────────────
RUN mkdir -p /home/agent/.npm-global && \
    chown -R agent:agent /home/agent/.npm-global
ENV NPM_CONFIG_PREFIX="/home/agent/.npm-global"
ENV PATH="/home/agent/.npm-global/bin:${PATH}"

USER agent

RUN echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> /home/agent/.bashrc

USER root
RUN claude update --yes 2>/dev/null || true
USER agent
