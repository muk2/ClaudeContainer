FROM docker/sandbox-templates:claude-code

USER root

# ── Core C++ toolchain + libraries (single apt layer) ───
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ gcc-13 g++-13 \
    clang clang-format clang-tidy clang-tools \
    lld lldb libc++-dev libc++abi-dev \
    gdb valgrind cmake make ninja-build \
    pkg-config autoconf automake libtool \
    zip unzip tar \
    libssl-dev libffi-dev zlib1g-dev \
    libboost-dev \
    libbenchmark-dev libgtest-dev \
    libfmt-dev nlohmann-json3-dev \
    libspdlog-dev libabsl-dev \
    libprotobuf-dev protobuf-compiler \
    libgrpc++-dev \
    strace ltrace binutils elfutils \
    cppcheck iwyu \
    doxygen graphviz \
    htop tree curl wget \
    && rm -rf /var/lib/apt/lists/*

# ── vcpkg (C++ package manager) ─────────────────────────
RUN git clone --depth 1 https://github.com/microsoft/vcpkg.git /opt/vcpkg && \
    /opt/vcpkg/bootstrap-vcpkg.sh && \
    ln -s /opt/vcpkg/vcpkg /usr/local/bin/vcpkg
ENV VCPKG_ROOT="/opt/vcpkg"

# ── Conan (C++ package manager) ─────────────────────────
RUN pip3 install --break-system-packages conan

# ── Set default to gcc-13 ───────────────────────────────
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 130 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-13

USER agent

USER root
RUN claude update --yes 2>/dev/null || true
USER agent
