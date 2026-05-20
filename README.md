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

## Continuous Integration

A Forgejo Actions workflow at [`.forgejo/workflows/build-containers.yml`](.forgejo/workflows/build-containers.yml) **lints** every Dockerfile touched by a pull request using [hadolint](https://github.com/hadolint/hadolint). It is path-filtered so PRs that only touch the README or docs skip CI entirely, and only the Dockerfiles whose contents changed in the diff are checked.

Currently the workflow runs `hadolint` (static analysis) rather than a real `docker build` because the configured `act_runner` doesn't have Docker available inside its job container. To upgrade to real build verification:

1. Mount the host Docker socket into the runner — edit `forgejo-runner` config so the job container gets `/var/run/docker.sock`, and ensure the runner host has at least 30 GB free disk.
2. Or switch the runner image to one that ships docker-in-docker (e.g. `catthehacker/ubuntu:full`).
3. Then replace the `Lint Dockerfiles` step in the workflow with `docker build` calls — see the commit history of this file for the prior build-based version.

Workflow-dispatch with `lint_all=true` checks every Dockerfile regardless of what changed.

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

# Windows Setup: Podman + PowerShell

Complete guide for running Claude Code dev containers on Windows using Podman. No Docker Desktop license needed — Podman is free and open source.

---

## Step 1: Install Podman

### Option A: Podman Desktop (GUI + CLI)

Download from [podman-desktop.io](https://podman-desktop.io). Run the installer. It handles WSL2 setup for you.

### Option B: CLI Only (winget)

Open PowerShell as **Administrator**:

```powershell
# Install WSL2 if not already installed
wsl --install

# Restart your computer, then:

# Install Podman
winget install RedHat.Podman
```

Close and reopen PowerShell after install.

### Optional: Install Windows Terminal

```powershell
winget install Microsoft.WindowsTerminal
```

---

## Step 2: Initialize the Podman Machine

Podman on Windows runs containers inside a lightweight Linux VM. Initialize it once:

```powershell
# Create the machine (uses WSL2 by default)
podman machine init

# Give it more resources (adjust to your hardware)
podman machine set --cpus 4 --memory 8192 --disk-size 100

# Start it
podman machine start
```

Verify:

```powershell
podman version
podman run quay.io/podman/hello
```

If the hello container prints a message, you're good.

---

## Step 3: Make Podman Work Like Docker

Podman commands are nearly identical to Docker. Set up an alias so all scripts work:

```powershell
# Add to your PowerShell profile
notepad $PROFILE

# Paste this line:
Set-Alias -Name docker -Value podman

# Save and close, then reload:
. $PROFILE
```

Now `docker build`, `docker run`, etc. all route through Podman.

---

## Step 4: Get the Dockerfiles

```powershell
# Clone the repo
git clone https://github.com/YOUR_USERNAME/claude-containers.git $HOME\.claude\sandboxes

# Or create manually
mkdir -p $HOME\.claude\sandboxes
# Copy all Dockerfile.* files there
```

---

## Step 5: Create Persistent Volumes

```powershell
podman volume create claude-config
podman volume create build-cache
```

---

## Step 6: Add PowerShell Functions

Open your PowerShell profile:

```powershell
notepad $PROFILE
```

Paste this entire block:

```powershell
# ── Claude Containers (Podman) ───────────────────────────

# Build a language image (run once per language)
function sb-lang {
    param([string]$Lang)
    podman build -t "claude-${Lang}:latest" `
        -f "$HOME\.claude\sandboxes\Dockerfile.$Lang" `
        "$HOME\.claude\sandboxes\"
}

# Run Claude in a project
function sb {
    param(
        [string]$Lang = "rust",
        [string]$Path = "."
    )
    $Project = (Resolve-Path $Path).Path
    $Name = "claude-$(Split-Path $Project -Leaf)"

    podman run -it --rm `
        --name $Name `
        -v "${Project}:/workspace" `
        -v "claude-config:/home/agent/.claude" `
        -v "build-cache:/home/agent/.cache" `
        -w /workspace `
        "claude-${Lang}:latest" `
        claude --dangerously-skip-permissions
}

# Shell into running container
function sb-shell {
    param([string]$Path = ".")
    $Project = (Resolve-Path $Path).Path
    $Name = "claude-$(Split-Path $Project -Leaf)"
    podman exec -it $Name bash
}

# Stop a container
function sb-down {
    param([string]$Path = ".")
    $Project = (Resolve-Path $Path).Path
    $Name = "claude-$(Split-Path $Project -Leaf)"
    podman stop $Name 2>$null
}

# List running Claude containers
function sb-ls {
    podman ps --filter "name=claude-" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
}

# Clean up disk space
function sb-prune {
    podman system prune -f
}

# Start/stop Podman machine
function sb-start { podman machine start }
function sb-stop { podman machine stop }
```

Save, close, reload:

```powershell
. $PROFILE
```

---

## Step 7: Build and Run

```powershell
# Build an image (one-time per language)
sb-lang rust
sb-lang python
sb-lang js

# Start Claude in a project
cd C:\Users\YourName\projects\my-app
sb rust

# Or with explicit path
sb rust C:\Users\YourName\projects\my-app

# Or current directory (default)
sb rust
```

First run will prompt browser login. After that, the `claude-config` volume saves your auth.

---

## Commands Reference

```powershell
# Build
sb-lang rust              # Build Rust image
sb-lang python            # Build Python image
sb-lang js                # Build JS/TS image
sb-lang all               # Build mega image

# Run
sb rust                   # Current dir, Rust toolchain
sb python .               # Current dir, Python
sb go C:\path\to\project  # Specific path, Go

# Side terminal (new PowerShell window while Claude runs)
sb-shell                  # Current dir
sb-shell C:\path          # Specific project

# Management
sb-ls                     # List running containers
sb-down                   # Stop current dir's container
sb-prune                  # Clean up disk

# Podman machine
sb-start                  # Start the Linux VM
sb-stop                   # Stop it (saves battery)
```

---

## Daily Workflow

```powershell
# Morning: start Podman machine
sb-start

# Work on a project
cd C:\Users\YourName\projects\my-app
sb rust
# Claude launches. Work with it. Ctrl+C when done.

# Side terminal (open new PowerShell tab)
sb-shell

# Switch projects
cd C:\Users\YourName\projects\ml-thing
sb python

# End of day: stop machine (optional, saves resources)
sb-stop
```

---

## Practicing a Language

```powershell
sb-lang lean
mkdir $HOME\practice\lean
cd $HOME\practice\lean
sb lean
# Ask Claude to teach you theorem proving

sb-lang ocaml
mkdir $HOME\practice\ocaml
cd $HOME\practice\ocaml
sb ocaml
# Ask Claude for Jane Street interview prep

sb-lang rust
mkdir $HOME\practice\rust
cd $HOME\practice\rust
sb rust
# Ask Claude to build ownership/lifetime exercises
```

---

## Podman Machine Management

The Podman machine is a lightweight Linux VM that runs your containers. It needs to be running before you use any `sb` command.

```powershell
# Check machine status
podman machine ls

# Start (do this after reboot or after sb-stop)
podman machine start

# Stop (frees RAM/CPU, run when done for the day)
podman machine stop

# Resize (if you need more resources)
podman machine stop
podman machine set --cpus 6 --memory 16384 --disk-size 150
podman machine start

# Nuclear reset (if something breaks)
podman machine rm
podman machine init
podman machine set --cpus 4 --memory 8192 --disk-size 100
podman machine start
```

---

## Disk Management

```powershell
# See what's using space
podman system df

# See image sizes
podman images

# Remove an image
podman rmi claude-cpp:latest

# Remove everything unused
podman system prune -a --volumes -f
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Cannot connect to Podman" | Start the machine: `podman machine start` |
| "no space left on device" | `podman system prune -a --volumes -f` |
| Machine won't start | `podman machine rm` then re-init |
| Slow file I/O | Normal with WSL2 mounts. Keep projects in WSL filesystem for speed |
| "permission denied" on volume | Try: `podman machine set --rootful` then restart |
| Login prompt every time | Check volume: `podman volume inspect claude-config` |
| Podman command not found | Close and reopen PowerShell, or check PATH |
| Need Docker compatibility | Add `Set-Alias -Name docker -Value podman` to `$PROFILE` |

---

## Why Podman Over Docker Desktop?

- **Free** — No license fees, even for commercial use at companies with 250+ employees
- **Rootless** — Containers run as your user, not as root. Better security by default
- **Docker-compatible** — Same commands, same Dockerfiles, same images
- **No daemon** — Podman doesn't run a background service eating resources
- **Open source** — Apache 2.0 license

---

## Architecture

All Dockerfiles work with Podman unchanged. Podman reads Dockerfiles natively (it calls them Containerfiles, but accepts both). Architecture auto-detection works the same:

- **Intel/AMD** → `x86_64` / `amd64`
- **ARM (Surface Pro X, Snapdragon)** → `aarch64` / `arm64`g