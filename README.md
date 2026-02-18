# ClaudeContainer
Devcontainer setup for claude for multiple toolchain ecosystems


# Claude Code Dev Containers

Pre-built Docker images with full language toolchains for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in isolated containers. Your code stays on your machine. The container is the sandbox. When you exit, the container is automatically destroyed.

---

## Available Images

| Image | What's Inside | Size |
|-------|--------------|------|
| `claude-js` | Node 22, Bun, npm, pnpm, TypeScript, Next.js, Prisma, Vitest | ~1.2GB |
| `claude-rust` | Rust stable, cargo tools, mold linker, clippy, rustfmt | ~2.5GB |
| `claude-python` | Python 3, uv, pytest, ruff, numpy, pandas, FastAPI | ~1.0GB |
| `claude-go` | Go 1.24, gopls, delve, staticcheck, golangci-lint | ~1.0GB |
| `claude-cpp` | GCC 13, Clang, CMake, Ninja, vcpkg, Conan, Boost | ~900MB |
| `claude-c` | GCC 13, Clang, GDB, Valgrind, CMake, Ninja | ~600MB |
| `claude-ocaml` | OCaml 5.2, opam, dune, Jane Street core, async | ~1.3GB |
| `claude-lean` | Lean 4, elan, Lake | ~600MB |
| `claude-csharp` | .NET SDK 9 + 8, dotnet-ef, BenchmarkDotNet | ~1.5GB |
| `claude-zig` | Zig 0.13, ZLS | ~600MB |
| `claude-all` | Everything above in one image | ~8-10GB |

---

## Mac Setup

### Step 1: Install a Container Runtime

You need one of these. Both replace Docker Desktop and run the same `docker` commands.

#### Option A: OrbStack (Recommended)

Fastest option. Native macOS app, starts in ~2 seconds, minimal RAM usage. Free for personal use.

```bash
brew install orbstack
open -a OrbStack
```

Leave it running (menu bar icon). Optional: OrbStack → Settings → "Start at login".

#### Option B: Colima

Free, open source, terminal-only. Slightly more setup but no GUI needed.

```bash
brew install colima docker

# Start with optimized settings for Apple Silicon
colima start \
    --cpu 4 \
    --memory 8 \
    --disk 100 \
    --vm-type vz \
    --vz-rosetta \
    --mount-type virtiofs
```

Adjust `--cpu` and `--memory` based on your machine (e.g., `--cpu 6 --memory 16` for Pro chips). To auto-start on login, add `colima start` to your shell profile or use `brew services start colima`.

#### Switching Between Runtimes

If you have both installed (or Docker Desktop too), use contexts to switch:

```bash
# See available contexts
docker context ls

# Switch to OrbStack
docker context use orbstack

# Switch to Colima
docker context use colima

# Switch to Docker Desktop
docker context use desktop-linux
```

The active context determines which runtime handles all `docker` commands. You only need one running at a time.

#### Verify

```bash
docker version
docker context ls    # confirm which runtime is active
```

### Step 2: Get the Dockerfiles

```bash
git clone https://github.com/YOUR_USERNAME/claude-containers.git ~/.claude/sandboxes
```

Or manually:

```bash
mkdir -p ~/.claude/sandboxes
# Copy all Dockerfile.* files into ~/.claude/sandboxes/
```

### Step 3: Create Persistent Volumes (One-Time)

```bash
docker volume create claude-config
docker volume create build-cache
```

- `claude-config` — Saves your Claude login so you only authenticate once.
- `build-cache` — Caches downloaded packages (cargo, pip, go modules) so they aren't re-downloaded every session.

### Step 4: Add Shell Aliases to `~/.zshrc`

```bash
# ── Claude Containers ────────────────────────────────────

# Build a language image (run once per language)
sb-lang() {
    docker build -t "claude-${1}:latest" \
        -f "$HOME/.claude/sandboxes/Dockerfile.${1}" \
        "$HOME/.claude/sandboxes/"
}

# Run Claude in a project
sb() {
    local lang="${1:-rust}"
    local project="$(cd "${2:-.}" && pwd)"
    local name="claude-$(basename "$project")"

    docker run -it --rm \
        --name "$name" \
        -v "$project":/workspace \
        -v claude-config:/home/agent/.claude \
        -v build-cache:/home/agent/.cache \
        -w /workspace \
        "claude-${lang}:latest" \
        claude --dangerously-skip-permissions
}

# Open a terminal inside a running container
sb-shell() {
    local project="$(cd "${1:-.}" && pwd)"
    docker exec -it "claude-$(basename "$project")" bash
}

# Stop a running container
sb-down() {
    local project="$(cd "${1:-.}" && pwd)"
    docker stop "claude-$(basename "$project")" 2>/dev/null
}

# List running Claude containers
alias sb-ls='docker ps --filter "name=claude-" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'

# Clean up disk space
alias sb-prune='docker system prune -f'
```

Then reload:

```bash
source ~/.zshrc
```

### Step 5: Build an Image

```bash
sb-lang rust
```

Takes 5-15 minutes the first time. Cached after that — only rebuild if you edit the Dockerfile.

### Step 6: First Run

```bash
sb rust ~/projects/my-app
```

On the **first run only**, Claude Code prompts you to log in via browser. After that, every `sb` command skips login automatically.

---

## Windows Setup (Docker Desktop + WSL2)

### Step 1: Install WSL2

PowerShell as Administrator:

```powershell
wsl --install
```

Restart when prompted.

### Step 2: Install Docker Desktop

Download from [docker.com](https://docker.com). Configure:

- Settings → General → Enable **"Use WSL 2 based engine"**
- Settings → Resources → WSL Integration → Enable for Ubuntu
- Settings → Resources → Disk image size → **128GB or higher**

### Step 3: Set Up in WSL2

Open **Ubuntu** from Start menu:

```bash
git clone https://github.com/YOUR_USERNAME/claude-containers.git ~/.claude/sandboxes
docker volume create claude-config
docker volume create build-cache
```

### Step 4: Add Aliases to `~/.bashrc`

Copy the same alias block from the Mac section into `~/.bashrc`, then:

```bash
source ~/.bashrc
```

### Step 5: Build and Run

```bash
sb-lang rust
sb rust ~/projects/my-app
```

### Alternative: No Containers

Claude Code runs natively on Windows:

1. Install [Git for Windows](https://git-scm.com/download/win)
2. Download Claude Code from [anthropic.com](https://anthropic.com)
3. Open Git Bash → `claude`

---

## Commands

### `sb-lang <language>` — Build an Image

**When:** Once per language, or after editing a Dockerfile.

```bash
sb-lang js            # JavaScript / TypeScript (Node, Bun, pnpm)
sb-lang rust          # Rust
sb-lang python        # Python
sb-lang go            # Go
sb-lang ocaml         # OCaml
sb-lang lean          # Lean 4
sb-lang csharp        # C# / .NET
sb-lang cpp           # C++
sb-lang c             # C
sb-lang zig           # Zig
sb-lang all           # mega image with every language
```

### `sb <language> [path]` — Run Claude

**When:** Every time you want to start working on a project.

The path is optional. If omitted, it uses your current directory.

```bash
# These are all equivalent:
cd ~/projects/my-app
sb rust                           # uses current directory
sb rust .                         # explicit current directory
sb rust ~/projects/my-app         # explicit full path

# Different languages:
sb js                             # JS/TS toolchain, current dir
sb python                         # Python toolchain, current dir
sb go ~/projects/api              # Go toolchain, specific path
sb all .                          # all languages, current dir
```

When you exit Claude (Ctrl+C, `/exit`, or type `exit`), the container is **automatically destroyed**. You do not need to clean anything up. Your project files on disk are untouched.

### `sb-shell [path]` — Side Terminal

**When:** You want your own terminal inside the same container while Claude is running. Open this in a new tab or tmux pane.

```bash
sb-shell                          # current directory's container
sb-shell ~/projects/my-app        # specific project's container
```

You and Claude share the same filesystem. You can run tests, inspect files, debug — while Claude works.

### `sb-ls` — List Running Containers

**When:** You want to see what's running.

```bash
sb-ls
```

### `sb-down [path]` — Stop a Container

**When:** You want to stop a container without being inside it (e.g., you closed the terminal by accident).

```bash
sb-down                           # stop current dir's container
sb-down ~/projects/my-app         # stop specific container
```

Normally you don't need this — exiting Claude already destroys the container.

### `sb-prune` — Free Disk Space

**When:** Docker is using too much disk.

```bash
sb-prune                          # removes stopped containers and dangling images
```

For a deeper clean:

```bash
docker system prune -a --volumes -f   # removes EVERYTHING unused (images, volumes, cache)
```

---

## Workflow

### Working on a Project

```bash
sb-lang rust                      # one-time: build image
cd ~/projects/my-app
sb rust                           # Claude launches with full toolchain
# ... work with Claude ...
# Ctrl+C or /exit when done
# Container auto-removes. Files on disk are saved.
```

### Side-by-Side with Tmux

```bash
tmux

# Left pane: Claude
sb rust

# Ctrl+b, % (split right)

# Right pane: You
sb-shell
```

### Multiple Projects

```bash
# Terminal 1
cd ~/projects/app-a && sb rust

# Terminal 2
cd ~/projects/ml-thing && sb python

# Both run simultaneously. Only the one actively compiling uses CPU.
```

---

## Practicing a Language

### Lean

```bash
sb-lang lean                      # one-time
mkdir -p ~/practice/lean
cd ~/practice/lean
sb lean
```

> Create a Lean 4 project that teaches me theorem proving. Start with
> simple propositions and build up to induction proofs.

### OCaml

```bash
sb-lang ocaml                     # one-time
mkdir -p ~/practice/ocaml
cd ~/practice/ocaml
sb ocaml
```

> Create exercises covering pattern matching, algebraic data types,
> modules, and functors using Jane Street's Core library.

### Rust

```bash
sb-lang rust                      # one-time
mkdir -p ~/practice/rust
cd ~/practice/rust
sb rust
```

> Build exercises that teach ownership, borrowing, and lifetimes.
> Each exercise should have a failing test I need to make pass.

### JavaScript / TypeScript

```bash
sb-lang js                        # one-time
mkdir -p ~/practice/fullstack
cd ~/practice/fullstack
sb js
```

> Build a Next.js app with Prisma and a REST API. Use TypeScript,
> Vitest for testing, and Biome for linting. Set up the full stack.

Claude has `node`, `bun`, `npm`, `pnpm`, `typescript`, `next`, `prisma`, `vitest`, and framework CLIs ready.

### Practice with Tmux

```bash
tmux
sb rust                           # left pane: Claude (teacher)
# Ctrl+b, %
sb-shell                          # right pane: you (student)

# Claude creates exercises on the left.
# You solve them on the right.
# Ask Claude for hints when stuck.
```

---

## Adding to a Repo

Let contributors spin up a Claude-ready environment for your project. Add `.devcontainer/` to your repo:

```
my-project/
├── .devcontainer/
│   ├── devcontainer.json
│   └── Dockerfile
├── src/
└── README.md
```

**`.devcontainer/devcontainer.json`:**

```json
{
    "name": "Claude Dev",
    "build": { "dockerfile": "Dockerfile" },
    "features": {
        "ghcr.io/anthropics/devcontainer-features/claude-code:latest": {}
    },
    "mounts": [
        "source=claude-config,target=/home/vscode/.claude,type=volume",
        "source=build-cache,target=/home/vscode/.cache,type=volume"
    ]
}
```

**`.devcontainer/Dockerfile`:** Copy your language Dockerfile but change the base:

```dockerfile
FROM ubuntu:24.04    # instead of docker/sandbox-templates:claude-code
```

**Contributors run:**

```bash
npm install -g @devcontainers/cli
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
claude --dangerously-skip-permissions
```

Or in VS Code: `Cmd+Shift+P` → "Reopen in Container"

---

## How It Works

```
┌──────────────────────────────────────┐
│           Your Machine               │
│  ~/projects/my-app ──────────────┐   │
│                                  │   │
│  OrbStack / Colima (Mac) or      │   │
│  Docker Desktop (Windows)        │   │
└──────────────────────────────────│───┘
                                   │ mounted at /workspace
┌──────────────────────────────────▼───┐
│         Docker Container             │
│  ┌────────────────────────────────┐  │
│  │ Language Toolchain             │  │
│  │ (Rust/Python/Go/OCaml/etc.)   │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Claude Code                    │  │
│  │ --dangerously-skip-permissions │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Persistent Volumes             │  │
│  │ claude-config → login/settings │  │
│  │ build-cache → cargo/pip/go     │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

- **Your files** stay on your machine, mounted into the container.
- **Claude** runs inside with full permissions — only inside the container.
- **Volumes** persist login and caches across sessions.
- **On exit**, the container is destroyed. Your files remain. Next `sb` is instant.

---

## Disk Management

```bash
docker system df                                # what's using space
docker images | grep claude                     # image sizes
docker rmi claude-cpp:latest                    # remove one image
docker system prune -a --volumes -f             # nuclear: remove everything unused
```

Only build images for languages you actively use.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Cannot connect to Docker daemon" | Start your runtime: `open -a OrbStack` or `colima start` |
| "no space left on device" | `docker system prune -a --volumes -f` |
| "permission denied" on /workspace | `chmod -R a+rw ~/projects/my-app` |
| Login not working | `docker volume rm claude-config && docker volume create claude-config` |
| Tools missing (cargo, python) | Rebuild image: `sb-lang rust` |
| "name already in use" | Container still running: `sb-down` then retry |
| Container exits immediately | Restart your runtime: quit and reopen OrbStack, or `colima stop && colima start` |
| Wrong runtime active | `docker context ls` to check, `docker context use <name>` to switch |
| Colima slow file I/O | Restart with `--mount-type virtiofs` and `--vm-type vz` |

---

## Architecture

All images auto-detect Apple Silicon (`arm64`) and Intel (`amd64`). No configuration needed.

## License

Dockerfiles are MIT. Claude Code is subject to [Anthropic's Terms of Service](https://www.anthropic.com/terms).