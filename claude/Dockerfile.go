FROM docker/sandbox-templates:claude-code

USER root

# ── System deps ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ gdb valgrind cmake make \
    pkg-config libssl-dev libffi-dev zlib1g-dev \
    libpq-dev postgresql-client \
    strace ltrace binutils elfutils \
    curl wget unzip htop tree \
    && rm -rf /var/lib/apt/lists/*

# ── Go (latest stable, detect arch) ─────────────────────
ARG GO_VERSION=1.24.4
RUN ARCH="$(dpkg --print-architecture)" && \
    case "$ARCH" in \
        amd64) GOARCH=amd64 ;; \
        arm64) GOARCH=arm64 ;; \
        *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" \
    | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"

# ── Go tools (combined into fewer layers) ───────────────
RUN GOPATH=/root/go go install golang.org/x/tools/gopls@latest && \
    GOPATH=/root/go go install github.com/go-delve/delve/cmd/dlv@latest && \
    GOPATH=/root/go go install honnef.co/go/tools/cmd/staticcheck@latest && \
    GOPATH=/root/go go install golang.org/x/tools/cmd/goimports@latest && \
    GOPATH=/root/go go install golang.org/x/vuln/cmd/govulncheck@latest && \
    GOPATH=/root/go go install github.com/google/pprof@latest \
    || true

RUN GOPATH=/root/go go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest || true
RUN GOPATH=/root/go go install github.com/cosmtrek/air@latest || true
RUN GOPATH=/root/go go install google.golang.org/protobuf/cmd/protoc-gen-go@latest || true
RUN GOPATH=/root/go go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest || true

# ── Copy Go tools to agent user ─────────────────────────
RUN mkdir -p /home/agent/go/bin && \
    cp -r /root/go/bin/* /home/agent/go/bin/ 2>/dev/null || true && \
    chown -R agent:agent /home/agent/go
ENV GOPATH="/home/agent/go"
ENV PATH="${GOPATH}/bin:/usr/local/go/bin:${PATH}"

# ── protoc ───────────────────────────────────────────────
RUN ARCH="$(dpkg --print-architecture)" && \
    case "$ARCH" in \
        amd64) PROTOC_ARCH=x86_64 ;; \
        arm64) PROTOC_ARCH=aarch_64 ;; \
    esac && \
    PROTOC_VERSION=25.2 && \
    curl -fsSL "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${PROTOC_ARCH}.zip" \
    -o /tmp/protoc.zip && \
    unzip /tmp/protoc.zip -d /usr/local && \
    rm /tmp/protoc.zip

USER agent

RUN echo 'export GOPATH="$HOME/go"' >> /home/agent/.bashrc && \
    echo 'export PATH="$GOPATH/bin:/usr/local/go/bin:$PATH"' >> /home/agent/.bashrc

USER root
RUN claude update --yes 2>/dev/null || true
USER agent
