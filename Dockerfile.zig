FROM docker/sandbox-templates:claude-code

USER root

# ── System deps ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ gdb valgrind cmake make \
    pkg-config libssl-dev libffi-dev zlib1g-dev \
    clang lld lldb libc-dev \
    strace ltrace binutils elfutils \
    curl wget unzip htop tree \
    && rm -rf /var/lib/apt/lists/*

# ── Zig (latest stable) ─────────────────────────────────
ARG ZIG_VERSION=0.13.0
RUN ARCH="$(dpkg --print-architecture)" && \
    case "$ARCH" in amd64) ZIGARCH=x86_64 ;; arm64) ZIGARCH=aarch64 ;; esac && \
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-${ZIGARCH}-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /usr/local && \
    ln -s /usr/local/zig-linux-${ZIGARCH}-${ZIG_VERSION}/zig /usr/local/bin/zig

# ── zls (Zig Language Server) ────────────────────────────
RUN git clone --depth 1 --branch ${ZIG_VERSION} \
        https://github.com/zigtools/zls.git /tmp/zls && \
    cd /tmp/zls && \
    zig build -Doptimize=ReleaseSafe && \
    cp zig-out/bin/zls /usr/local/bin/zls && \
    rm -rf /tmp/zls

# ── Verify install ───────────────────────────────────────
RUN zig version && zls --version

USER agent
