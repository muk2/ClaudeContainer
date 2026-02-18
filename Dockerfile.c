FROM docker/sandbox-templates:claude-code

USER root

# ── Core C toolchain + libraries (single apt layer) ─────
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc gcc-13 \
    clang clang-format clang-tidy clang-tools \
    lld lldb \
    gdb gdbserver valgrind cmake make ninja-build \
    pkg-config autoconf automake libtool \
    nasm yasm \
    libssl-dev libffi-dev zlib1g-dev \
    libcurl4-openssl-dev libxml2-dev \
    libsqlite3-dev libpq-dev \
    libevent-dev libev-dev libuv1-dev \
    libpcre3-dev libjansson-dev \
    libcmocka-dev \
    strace ltrace binutils elfutils \
    cppcheck \
    doxygen graphviz \
    htop tree curl wget unzip xxd \
    && rm -rf /var/lib/apt/lists/*

# Note: libcriterion-dev removed — not in default Ubuntu repos, install via vcpkg if needed
# Note: splint removed — often unavailable on arm64
# Note: linux-tools-* removed — requires matching kernel, fails in containers

# ── Set default to gcc-13 ───────────────────────────────
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 130

USER agent
