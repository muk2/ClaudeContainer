# OpenCode Dev Containers

AI coding agents in Docker. Full toolchains, GitHub CLI, Gitea CLI. Spawn per-project containers. Switch between providers — OpenCode's free built-in model, Groq, DeepSeek, OpenRouter, Anthropic, OpenAI — with a flag.

```
┌──────────────────────────────────────────┐
│              Mac / Linux                 │
│                                          │
│  OrbStack (or Docker)                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ oc-rust  │ │ oc-js    │ │ oc-python│ │
│  │ OpenCode │ │ OpenCode │ │ OpenCode │ │
│  │ gh + tea │ │ gh + tea │ │ gh + tea │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│       └─────── Cloud APIs ──────┘        │
└──────────────────────────────────────────┘
```

**Cost: $0 by default.** OpenCode ships with a free built-in model. Add free-tier API keys (Groq, DeepSeek) for faster/better options. Pay only if you want Claude or GPT.

---

## Quick Start

```bash
# 1. Install OrbStack
brew install orbstack
open -a OrbStack

# 2. Clone and build
git clone https://github.com/YOUR_USER/opencode-containers.git ~/.opencode/containers
oc-lang rust

# 3. Create volumes
docker volume create oc-config oc-auth oc-gh oc-tea build-cache

# 4. Auth (one-time)
oc-gh-login             # GitHub CLI
oc-tea-login            # Gitea (if you use it)

# 5. Code
cd ~/projects/my-app
oc rust                 # free built-in model
oc rust -p groq         # free Groq API
oc rust -p anthropic    # Claude (paid)
```

---

## Setup

### 1. Install OrbStack

```bash
brew install orbstack
open -a OrbStack
```

OrbStack is a lightweight Docker runtime for Mac. It replaces Docker Desktop.

### 2. Clone This Repo

```bash
git clone https://github.com/YOUR_USER/opencode-containers.git ~/.opencode/containers
```

### 3. Create Persistent Volumes

```bash
docker volume create oc-config      # OpenCode sessions + settings
docker volume create oc-auth        # OpenCode provider API keys
docker volume create oc-gh          # GitHub CLI auth
docker volume create oc-tea         # Gitea tea CLI auth
docker volume create build-cache    # Cargo/pip/go/npm cache
```

### 4. Add Shell Aliases to `~/.zshrc`

```bash
# ── OpenCode Containers ──────────────────────────────────

OC_DIR="$HOME/.opencode/containers"

# Build an image (run once per language)
oc-lang() {
    docker build -t "oc-${1}:latest" \
        -f "$OC_DIR/Dockerfile.oc-${1}" \
        "$OC_DIR/"
}

# Internal helper — all oc commands route through here
_oc_run() {
    local name="$1"; shift
    local image="$1"; shift
    local project="$1"; shift

    local env_args=()
    while [[ "$1" == -e ]]; do
        env_args+=(-e "$2"); shift 2
    done

    docker run -it --rm \
        --name "$name" \
        --add-host=host.docker.internal:host-gateway \
        -v "$project":/workspace \
        -v oc-config:/home/agent/.config/opencode \
        -v oc-auth:/home/agent/.local/share/opencode \
        -v oc-gh:/home/agent/.config/gh \
        -v oc-tea:/home/agent/.config/tea \
        -v build-cache:/home/agent/.cache \
        -w /workspace \
        "${env_args[@]}" \
        "$image" \
        "$@"
}

# Launch OpenCode TUI
# Usage: oc <lang> [path] [-p <provider>]
# Supported languages: base, rust, python, go, js, c, cpp, csharp, zig, lean, ocaml, swift
oc() {
    local lang="${1:-base}"; shift
    local project="." provider=""
    OC_PROVIDER_ENV=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--provider) provider="$2"; shift 2 ;;
            *) project="$1"; shift ;;
        esac
    done
    project="$(cd "$project" && pwd)"

    local env_args=()
    if [[ -n "$provider" ]]; then
        _oc_load_provider "$provider" || return 1
        env_args=(${=OC_PROVIDER_ENV})
    fi

    _oc_run "oc-$(basename "$project")" "oc-${lang}:latest" "$project" \
        "${env_args[@]}" opencode
}

# Run a single prompt headless (no TUI)
# Usage: oc-run <lang> [path] [-p <provider>] "prompt"
oc-run() {
    local lang="${1:-base}"; shift
    local project="." provider="" prompt=""
    OC_PROVIDER_ENV=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--provider) provider="$2"; shift 2 ;;
            -*) shift ;;
            *)
                if [[ -d "$1" ]]; then project="$1"; shift
                else prompt="$*"; break
                fi ;;
        esac
    done
    project="$(cd "$project" && pwd)"

    local env_args=()
    if [[ -n "$provider" ]]; then
        _oc_load_provider "$provider" || return 1
        env_args=(${=OC_PROVIDER_ENV})
    fi

    _oc_run "oc-run-$$" "oc-${lang}:latest" "$project" \
        "${env_args[@]}" opencode run "$prompt"
}

# Load provider API key from ~/.opencode/providers or env
# Sets OC_PROVIDER_ENV as side-effect (e.g. "ANTHROPIC_API_KEY=sk-ant-xxx")
_oc_load_provider() {
    local provider="$1"
    local key_file="$HOME/.opencode/providers/$provider"
    local env_var

    case "$provider" in
        anthropic|claude)  env_var="ANTHROPIC_API_KEY" ;;
        openai|gpt)        env_var="OPENAI_API_KEY" ;;
        google|gemini)     env_var="GOOGLE_API_KEY" ;;
        groq)              env_var="GROQ_API_KEY" ;;
        deepseek)          env_var="DEEPSEEK_API_KEY" ;;
        openrouter)        env_var="OPENROUTER_API_KEY" ;;
        *)                 env_var="${(U)provider}_API_KEY" ;;
    esac

    local api_key="${(P)env_var}"
    if [[ -z "$api_key" && -f "$key_file" ]]; then
        api_key="$(cat "$key_file")"
    fi

    if [[ -z "$api_key" ]]; then
        echo "No API key found for '$provider'."
        echo "Set it with:  oc-add-key $provider"
        echo "Or export:    export $env_var=sk-..."
        return 1
    fi

    OC_PROVIDER_ENV="-e $env_var=$api_key"
}

# Save an API key locally
oc-add-key() {
    local provider="${1:?Usage: oc-add-key <provider>}"
    mkdir -p "$HOME/.opencode/providers"
    echo -n "API key for $provider: "
    read -rs api_key
    echo
    echo "$api_key" > "$HOME/.opencode/providers/$provider"
    chmod 600 "$HOME/.opencode/providers/$provider"
    echo "Saved to ~/.opencode/providers/$provider"
}

# Open bash inside a running OpenCode container
oc-shell() {
    docker exec -it "oc-$(basename "$(cd "${1:-.}" && pwd)")" bash
}

# One-time auth (saved to volumes, shared across all containers)
oc-gh-login() {
    docker run -it --rm \
        -v oc-gh:/home/agent/.config/gh \
        "oc-${1:-base}:latest" gh auth login
}
oc-tea-login() {
    docker run -it --rm \
        -v oc-tea:/home/agent/.config/tea \
        "oc-${1:-base}:latest" tea login add
}
oc-provider-login() {
    docker run -it --rm \
        -v oc-auth:/home/agent/.local/share/opencode \
        "oc-${1:-base}:latest" opencode auth login
}

# Stop container
oc-down() {
    docker stop "oc-$(basename "$(cd "${1:-.}" && pwd)")" 2>/dev/null
}

# List all running OpenCode containers
alias oc-ls='docker ps --filter "name=oc-" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'

# Clean up unused Docker resources
alias oc-prune='docker system prune -f'
```

Reload your shell:

```bash
source ~/.zshrc
```

### 5. Build Images

Build only the languages you need. Each image includes OpenCode, `gh`, `tea`, and `git`.

```bash
oc-lang base       # OpenCode only, no toolchain (~800MB)
oc-lang rust       # + Rust stable, cargo, clippy, mold (~2.5GB)
oc-lang python     # + Python 3, uv, pytest, ruff, pandas (~1.2GB)
oc-lang go         # + Go 1.24, gopls, delve, golangci-lint (~1.1GB)
oc-lang js         # + Node 22, Bun, pnpm, TypeScript (~1.3GB)
oc-lang c          # + GCC 13, Clang, GDB, Valgrind, CMake (~700MB)
oc-lang cpp        # + GCC 13, Clang, Boost, vcpkg, Conan (~1GB)
oc-lang csharp     # + .NET SDK 9 + 8, dotnet-ef, csharpier (~1.5GB)
oc-lang zig        # + Zig 0.13, ZLS (~700MB)
oc-lang lean       # + Lean 4, elan, Lake (~700MB)
oc-lang ocaml      # + OCaml 5.2, opam, dune, Jane Street core (~1.3GB)
oc-lang swift      # + Swift 6.0, swift-format, SourceKit-LSP, lldb (~3GB)
```

### 6. Authenticate (One-Time)

```bash
# GitHub CLI (required for gh operations)
oc-gh-login

# Gitea CLI (only if you use a Gitea instance)
oc-tea-login
```

### 7. Add API Keys (Optional)

OpenCode works out of the box with its free built-in model. Add keys for other providers if you want them:

```bash
oc-add-key groq          # free tier — Llama/Mixtral, very fast
oc-add-key deepseek      # very cheap — DeepSeek Coder
oc-add-key openrouter    # aggregator — access dozens of models
oc-add-key anthropic     # paid — Claude (best quality)
oc-add-key openai        # paid — GPT
oc-add-key google        # paid — Gemini
```

Keys are saved to `~/.opencode/providers/<name>` (plaintext, `chmod 600`). You only do this once per provider.

---

## Usage

### Launch OpenCode

```bash
cd ~/projects/my-app

# Free built-in model (no key needed)
oc rust
oc python
oc go
oc js
oc c
oc cpp
oc csharp
oc zig
oc lean
oc ocaml
oc swift

# With a specific provider
oc rust -p groq
oc rust -p deepseek
oc rust -p anthropic
oc rust -p openai

# Explicit project path
oc rust ~/projects/backend
oc python ~/projects/ml -p groq
```

Your project is mounted at `/workspace`. Exit with Ctrl+C, `q`, or `exit`. Container auto-removes. Project files persist on host.

### Headless Mode (Single Prompt, No TUI)

```bash
oc-run rust . "Fix all clippy warnings, run tests, commit if green"
oc-run python . "Add type hints to every function and run mypy"
oc-run js . -p groq "Upgrade all deps and fix breaking changes"
oc-run go . -p anthropic "Write table-driven tests for every exported function"
oc-run csharp . "Run dotnet test and fix any failures"
```

### Multiple Containers (Parallel)

```bash
# Terminal 1
cd ~/projects/backend && oc rust -p groq

# Terminal 2
cd ~/projects/frontend && oc js

# Terminal 3
cd ~/projects/ml && oc python -p deepseek
```

Each project gets its own named container. All share auth volumes.

### Side Terminal

```bash
oc-shell                      # current directory's container
oc-shell ~/projects/backend   # specific project's container
```

---

## Switching Providers

### The `-p` Flag

```bash
oc rust                     # free built-in model
oc rust -p groq             # free Groq (Llama 4, very fast)
oc rust -p deepseek         # DeepSeek Coder (cheap, good at code)
oc rust -p openrouter       # OpenRouter (pick any model in TUI)
oc rust -p anthropic        # Claude (best quality, paid)
oc rust -p openai           # GPT (paid)
oc rust -p google           # Gemini (paid)
```

### Provider Lookup Order

1. Environment variable (e.g. `ANTHROPIC_API_KEY=sk-ant-xxx oc rust -p anthropic`)
2. Saved key file (`~/.opencode/providers/anthropic`)
3. If neither found, prints instructions and exits

### Supported Providers

| Flag | Env Var | Aliases | Cost |
|------|---------|---------|------|
| *(none)* | — | — | Free (OpenCode built-in) |
| `groq` | `GROQ_API_KEY` | — | Free tier |
| `deepseek` | `DEEPSEEK_API_KEY` | — | Very cheap |
| `openrouter` | `OPENROUTER_API_KEY` | — | Varies by model |
| `anthropic` | `ANTHROPIC_API_KEY` | `claude` | Paid |
| `openai` | `OPENAI_API_KEY` | `gpt` | Paid |
| `google` | `GOOGLE_API_KEY` | `gemini` | Paid |

### Switching Inside the TUI

Type `/models` to see all available models from the current provider and switch between them without restarting.

### OpenCode Built-in Auth (Alternative)

If you prefer OpenCode's built-in auth system instead of key files:

```bash
oc-provider-login
# Interactive prompt — select provider, paste API key
# Saved to oc-auth Docker volume, shared across all containers
```

---

## Git / GitHub / Gitea

All containers have `git`, `gh` (GitHub CLI), and `tea` (Gitea CLI) pre-installed. Auth persists via Docker volumes.

```bash
# GitHub via OpenCode
oc-run rust . "Create a PR for the current branch with a summary"
oc-run rust . "Review the latest open PR and post inline comments"

# Gitea via OpenCode
oc-run rust . "List open issues on this Gitea repo"
oc-run rust . "Create a pull request targeting main"

# Direct CLI inside a container
oc-shell
$ gh pr list
$ gh issue create --title "Bug" --body "Description"
$ tea issues list
$ tea pulls create --base main --head feature-branch
```

---

## Images

Every image includes: OpenCode, GitHub CLI (`gh`), Gitea CLI (`tea`), git, git-lfs, Node 22, ripgrep, fd, jq, tree, htop, build-essential.

| Image | Toolchain | Key Packages | Size |
|-------|-----------|-------------|------|
| `oc-base` | None | — | ~800MB |
| `oc-rust` | Rust stable | cargo, clippy, rustfmt, rust-analyzer, mold, cargo-nextest | ~2.5GB |
| `oc-python` | Python 3 | uv, pytest, ruff, mypy, pyright, pandas, FastAPI, SQLAlchemy | ~1.2GB |
| `oc-go` | Go 1.24 | gopls, delve, staticcheck, goimports, golangci-lint | ~1.1GB |
| `oc-js` | Node 22 | Bun, pnpm, TypeScript, tsx, ESLint, Prettier, Vitest, Next.js, Prisma | ~1.3GB |
| `oc-c` | GCC 13 + Clang | GDB, Valgrind, CMake, Ninja, nasm, cppcheck | ~700MB |
| `oc-cpp` | GCC 13 + Clang | Boost, vcpkg, Conan, gRPC, protobuf, Google Test, fmt | ~1GB |
| `oc-csharp` | .NET SDK 9 + 8 | dotnet-ef, dotnet-format, csharpier | ~1.5GB |
| `oc-zig` | Zig 0.13 | ZLS (Zig Language Server) | ~700MB |
| `oc-lean` | Lean 4 | elan, Lake | ~700MB |
| `oc-ocaml` | OCaml 5.2 | opam, dune, utop, merlin, ocaml-lsp-server, Jane Street core, async | ~1.3GB |
| `oc-swift` | Swift 6.0.3 | swift-format, SourceKit-LSP, lldb | ~3GB |

---

## Volumes

| Volume | Mounted At (in container) | Purpose |
|--------|---------------------------|---------|
| `oc-config` | `~/.config/opencode` | OpenCode sessions, settings, model preferences |
| `oc-auth` | `~/.local/share/opencode` | Cloud provider API keys (from `opencode auth login`) |
| `oc-gh` | `~/.config/gh` | GitHub CLI auth (from `gh auth login`) |
| `oc-tea` | `~/.config/tea` | Gitea tea CLI auth (from `tea login add`) |
| `build-cache` | `~/.cache` | Cargo registry, pip cache, Go modules, npm cache |

All volumes persist across container restarts and image rebuilds. Shared by every `oc-*` container.

---

## Repo Structure

```
opencode-containers/
├── README.md                 # This file
├── entrypoint.sh             # Fixes volume permissions at container start
├── Dockerfile.oc-base        # OpenCode, no toolchain
├── Dockerfile.oc-rust        # OpenCode + Rust
├── Dockerfile.oc-python      # OpenCode + Python
├── Dockerfile.oc-go          # OpenCode + Go
├── Dockerfile.oc-js          # OpenCode + JS/TS
├── Dockerfile.oc-c           # OpenCode + C
├── Dockerfile.oc-cpp         # OpenCode + C++
├── Dockerfile.oc-csharp      # OpenCode + C#
├── Dockerfile.oc-zig         # OpenCode + Zig
├── Dockerfile.oc-lean        # OpenCode + Lean 4
├── Dockerfile.oc-ocaml       # OpenCode + OCaml
└── Dockerfile.oc-swift       # OpenCode + Swift
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `gh` not authenticated | Run `oc-gh-login` (one-time) |
| `tea` not authenticated | Run `oc-tea-login` (one-time) |
| "No API key found" | Run `oc-add-key <provider>` |
| Container name already in use | `oc-down` then retry |
| OrbStack not running | `open -a OrbStack` |
| Permission denied in container | Rebuild image: `oc-lang <lang>` |
| OCaml: `ocaml` not on PATH | Run `eval $(opam env)` (done automatically via `.bashrc`) |
| Lean: elan permission error | Fixed in Dockerfile. If it recurs, set `ELAN_HOME=$HOME/.elan` |
| Want to switch provider mid-session | Type `/models` in the TUI, or exit and restart with `-p` |

---

## Appendix: Local Ollama (Optional)

If you want fully offline, local inference — install Ollama and configure it as a provider. Note: local models on Apple Silicon run at ~10-15 tok/sec vs 50-100+ tok/sec from cloud APIs. Best used when offline or working with sensitive code.

### Install

```bash
brew install ollama
```

### Pull a Model + Fix Context Window

Ollama defaults to 4096 tokens. OpenCode needs at least 16k for tool calling. You **must** increase `num_ctx`.

```bash
# 36GB Mac
ollama pull qwen3-coder:30b
ollama run qwen3-coder:30b
>>> /set parameter num_ctx 32768
>>> /save qwen3-coder:30b-32k
>>> /bye

# 24GB Mac
ollama pull qwen3:14b
ollama run qwen3:14b
>>> /set parameter num_ctx 16384
>>> /save qwen3:14b-16k
>>> /bye

# Any Mac (lightweight)
ollama pull qwen3:8b
ollama run qwen3:8b
>>> /set parameter num_ctx 16384
>>> /save qwen3:8b-16k
>>> /bye
```

### Start Ollama

```bash
# Add to ~/.zshrc:
alias ollama-start='OLLAMA_KEEP_ALIVE=5m OLLAMA_MAX_LOADED_MODELS=1 ollama serve &'
alias ollama-status='ollama ps && echo && memory_pressure | head -3'
ollama-unload() {
    local m=$(ollama ps 2>/dev/null | tail -1 | awk '{print $1}')
    [ -n "$m" ] && [ "$m" != "NAME" ] && \
        curl -s localhost:11434/api/generate -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null && \
        echo "Unloaded $m" || echo "Nothing loaded"
}
```

```bash
ollama-start
```

### Use It

The Dockerfiles already include Ollama configuration pointing to `host.docker.internal:11434`. Just start Ollama and launch OpenCode without `-p`:

```bash
ollama-start
oc rust          # will use Ollama models configured in opencode.json
```

Use `/models` in the TUI to switch between the configured Ollama models.

### Memory Budget

| Mac | Model | RAM Used | Free |
|-----|-------|----------|------|
| 24GB | `qwen3:14b-16k` | ~9GB | ~5GB after apps |
| 36GB | `qwen3-coder:30b-32k` | ~20GB | ~3GB after apps |

Run `ollama-unload` to free model RAM instantly. macOS showing 32/36GB "used" is normal — it's file cache, not pressure. Check `memory_pressure` for the real picture.

---

## License

All Dockerfiles in this repo are MIT. OpenCode is MIT.
