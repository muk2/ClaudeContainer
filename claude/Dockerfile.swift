FROM docker/sandbox-templates:claude-code

USER root

# ── System deps ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ cmake make \
    pkg-config libssl-dev libffi-dev zlib1g-dev \
    libicu-dev libcurl4-openssl-dev libxml2-dev \
    libncurses-dev libedit-dev \
    curl wget unzip htop tree strace \
    && rm -rf /var/lib/apt/lists/*

# ── Swift toolchain (official tarball) ───────────────────
ENV SWIFT_VERSION=6.0.3
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then \
        SWIFT_ARCH=aarch64; \
        SWIFT_SUFFIX="-${SWIFT_ARCH}"; \
    else \
        SWIFT_ARCH=x86_64; \
        SWIFT_SUFFIX=""; \
    fi && \
    PLATFORM_DIR="ubuntu2404${SWIFT_SUFFIX}" && \
    TARBALL="swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04${SWIFT_SUFFIX}.tar.gz" && \
    URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/${PLATFORM_DIR}/swift-${SWIFT_VERSION}-RELEASE/${TARBALL}" && \
    curl -fsSL "$URL" -o /tmp/swift.tar.gz && \
    mkdir -p /usr/share/swift && \
    tar xzf /tmp/swift.tar.gz -C /usr/share/swift --strip-components=1 && \
    rm /tmp/swift.tar.gz

ENV PATH="/usr/share/swift/usr/bin:${PATH}"

RUN ln -s /usr/share/swift/usr/bin/swift /usr/local/bin/swift && \
    ln -s /usr/share/swift/usr/bin/swiftc /usr/local/bin/swiftc && \
    ln -s /usr/share/swift/usr/bin/sourcekit-lsp /usr/local/bin/sourcekit-lsp && \
    ln -s /usr/share/swift/usr/bin/lldb /usr/local/bin/lldb || true

# ── Swift developer tools ────────────────────────────────
RUN mkdir -p /home/agent/.local/bin && \
    chown -R agent:agent /home/agent/.local

USER agent
RUN mkdir -p /tmp/swift-format && cd /tmp/swift-format && \
    git clone --depth 1 https://github.com/swiftlang/swift-format.git . && \
    swift build -c release --product swift-format && \
    cp .build/release/swift-format /home/agent/.local/bin/ && \
    rm -rf /tmp/swift-format || true

RUN echo 'export PATH="$HOME/.local/bin:/usr/share/swift/usr/bin:$PATH"' >> /home/agent/.bashrc
