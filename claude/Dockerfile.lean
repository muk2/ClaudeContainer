FROM docker/sandbox-templates:claude-code

USER root

# ── System deps ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ cmake make \
    pkg-config libssl-dev libffi-dev zlib1g-dev \
    libgmp-dev \
    curl wget unzip htop tree \
    && rm -rf /var/lib/apt/lists/*

# ── elan (Lean version manager, like rustup) ────────────
ENV ELAN_HOME="/usr/local/elan"
RUN curl https://elan.lean-lang.org/elan-init.sh -sSf \
    | ELAN_HOME="$ELAN_HOME" sh -s -- -y --no-modify-path --default-toolchain leanprover/lean4:stable && \
    chmod -R a+rx "$ELAN_HOME"
ENV PATH="${ELAN_HOME}/bin:${PATH}"

# ── Verify install ───────────────────────────────────────
RUN lean --version && lake --version

USER agent

# ── Shell setup ──────────────────────────────────────────
RUN echo 'export ELAN_HOME="/usr/local/elan"' >> /home/agent/.bashrc && \
    echo 'export PATH="$ELAN_HOME/bin:$PATH"' >> /home/agent/.bashrc

USER root
RUN claude update --yes 2>/dev/null || true
USER agent
