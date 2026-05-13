#!/usr/bin/env bash
# Canton DevRel Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/canton-foundation/canton-devrel/main/install.sh | bash
set -euo pipefail

REPO=""
INSTALL_DIR="$HOME/.canton-devrel"
BIN_DIR="$HOME/.local/bin"
VERSION="0.1.0"

# ─── Colors ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
  echo ""
  echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}${BOLD}│   Canton DevRel Installer  v${VERSION}        │${NC}"
  echo -e "${CYAN}${BOLD}│   Canton Foundation Developer Relations  │${NC}"
  echo -e "${CYAN}${BOLD}└─────────────────────────────────────────┘${NC}"
  echo ""
}

ok()   { echo -e "${GREEN}✓${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
err()  { echo -e "${RED}✗${NC}  $*"; }
step() { echo -e "${BOLD}▶${NC}  $*"; }

# ─── Platform check ───────────────────────────────────────────────────────────

print_banner

OS="$(uname -s)"
case "$OS" in
  Darwin) ok "macOS detected" ;;
  Linux)  ok "Linux detected" ;;
  *)
    err "Unsupported OS: $OS"
    echo "  canton devrel supports macOS and Linux only."
    echo "  Windows: use WSL 2."
    exit 1
    ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ok "Architecture: x86_64" ;;
  arm64|aarch64) ok "Architecture: arm64 (Apple Silicon / ARM)" ;;
  *)
    err "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo ""

# ─── Dependency checks ────────────────────────────────────────────────────────

step "Checking dependencies..."
echo ""

MISSING_DEPS=()

check_dep() {
  local cmd="$1"
  local install_hint="$2"
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd found ($(command -v "$cmd"))"
  else
    err "$cmd not found"
    warn "  Install: $install_hint"
    MISSING_DEPS+=("$cmd")
  fi
}

check_dep "docker"  "Install Docker Desktop from https://www.docker.com/products/docker-desktop/"
check_dep "curl"    "brew install curl  (macOS) | sudo apt install curl  (Linux)"
check_dep "jq"      "brew install jq    (macOS) | sudo apt install jq    (Linux)"
check_dep "git"     "brew install git   (macOS) | sudo apt install git   (Linux)"

echo ""

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
  err "Missing required dependencies: ${MISSING_DEPS[*]}"
  echo "  Install them and re-run the installer."
  exit 1
fi

# Check Docker is running
if ! docker info &>/dev/null; then
  err "Docker is installed but not running. Start Docker Desktop and re-run."
  exit 1
fi
ok "Docker is running"

# Check Docker Compose v2
if ! docker compose version &>/dev/null; then
  err "Docker Compose v2 not found. Update Docker Desktop (it's included in recent versions)."
  exit 1
fi
ok "Docker Compose v2 found"

# Warn about memory
DOCKER_MEMORY_BYTES=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
DOCKER_MEMORY_GB=$(( DOCKER_MEMORY_BYTES / 1024 / 1024 / 1024 ))
if [ "$DOCKER_MEMORY_GB" -lt 7 ]; then
  warn "Docker has ~${DOCKER_MEMORY_GB}GB memory. LocalNet needs at least 8GB."
  warn "Go to Docker Desktop → Settings → Resources → Memory and increase it."
else
  ok "Docker memory: ~${DOCKER_MEMORY_GB}GB"
fi

echo ""

# ─── Download ─────────────────────────────────────────────────────────────────

step "Installing canton devrel to $INSTALL_DIR..."
echo ""

# Remove existing installation if present
if [ -d "$INSTALL_DIR" ]; then
  warn "Existing installation found at $INSTALL_DIR — upgrading."
  rm -rf "$INSTALL_DIR"
fi

# Clone the repo
if command -v git &>/dev/null; then
  git clone --depth=1 --quiet \
    "https://github.com/${REPO}.git" \
    "$INSTALL_DIR" 2>/dev/null || {
      # Fallback: download tarball if git clone fails
      warn "git clone failed, trying tarball download..."
      mkdir -p "$INSTALL_DIR"
      curl -fsSL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" | \
        tar -xz --strip-components=1 -C "$INSTALL_DIR"
    }
else
  mkdir -p "$INSTALL_DIR"
  curl -fsSL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" | \
    tar -xz --strip-components=1 -C "$INSTALL_DIR"
fi

ok "Downloaded to $INSTALL_DIR"

# Make all scripts executable
chmod +x "$INSTALL_DIR/canton"
chmod +x "$INSTALL_DIR/scripts/"*.sh
chmod +x "$INSTALL_DIR/scripts/lib/"*.sh 2>/dev/null || true

# ─── PATH setup ───────────────────────────────────────────────────────────────

step "Setting up PATH..."
echo ""

# Create ~/.local/bin and symlink the canton binary
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/canton" "$BIN_DIR/canton"
ok "Symlinked: $BIN_DIR/canton → $INSTALL_DIR/canton"

# Detect shell and add to PATH if not already there
SHELL_NAME="$(basename "$SHELL")"
PATH_LINE="export PATH=\"\$HOME/.local/bin:\$PATH\""
CANTON_ENV_LINE="export CANTON_DEVREL_DIR=\"$INSTALL_DIR\""

add_to_shell_rc() {
  local rc_file="$1"
  if [ -f "$rc_file" ]; then
    if ! grep -q '.local/bin' "$rc_file" 2>/dev/null; then
      echo "" >> "$rc_file"
      echo "# canton devrel" >> "$rc_file"
      echo "$PATH_LINE" >> "$rc_file"
      echo "$CANTON_ENV_LINE" >> "$rc_file"
      ok "Added to $rc_file"
    else
      ok "$rc_file already has ~/.local/bin in PATH"
      # Still add CANTON_DEVREL_DIR if missing
      if ! grep -q 'CANTON_DEVREL_DIR' "$rc_file" 2>/dev/null; then
        echo "$CANTON_ENV_LINE" >> "$rc_file"
      fi
    fi
  fi
}

case "$SHELL_NAME" in
  zsh)
    add_to_shell_rc "$HOME/.zshrc"
    ;;
  bash)
    add_to_shell_rc "$HOME/.bashrc"
    add_to_shell_rc "$HOME/.bash_profile"
    ;;
  fish)
    warn "Fish shell detected. Add this manually to ~/.config/fish/config.fish:"
    echo "    set -x PATH \$HOME/.local/bin \$PATH"
    echo "    set -x CANTON_DEVREL_DIR $INSTALL_DIR"
    ;;
  *)
    warn "Unknown shell: $SHELL_NAME. Add this to your shell RC file manually:"
    echo "    $PATH_LINE"
    echo "    $CANTON_ENV_LINE"
    ;;
esac

echo ""

# ─── /etc/hosts check ─────────────────────────────────────────────────────────

step "Checking /etc/hosts for *.localhost domains..."
echo ""

HOSTS_NEEDED=()
for domain in wallet.localhost scan.localhost keycloak.localhost; do
  if ! grep -q "$domain" /etc/hosts 2>/dev/null; then
    HOSTS_NEEDED+=("$domain")
  fi
done

if [ ${#HOSTS_NEEDED[@]} -gt 0 ]; then
  warn "Missing from /etc/hosts: ${HOSTS_NEEDED[*]}"
  echo ""
  read -rp "  Add them now? (requires sudo) [y/N] " add_hosts
  add_hosts_lower="$(echo "$add_hosts" | tr '[:upper:]' '[:lower:]')"
  if [ "$add_hosts_lower" = "y" ]; then
    echo "127.0.0.1  wallet.localhost scan.localhost keycloak.localhost" | \
      sudo tee -a /etc/hosts > /dev/null
    ok "Added to /etc/hosts"
  else
    warn "Skipped. Wallet and Scan UIs may not resolve in the browser."
    warn "Add manually: echo '127.0.0.1  wallet.localhost scan.localhost keycloak.localhost' | sudo tee -a /etc/hosts"
  fi
else
  ok "All *.localhost domains already in /etc/hosts"
fi

echo ""

# ─── Done ─────────────────────────────────────────────────────────────────────

echo -e "${GREEN}${BOLD}┌─────────────────────────────────────────┐${NC}"
echo -e "${GREEN}${BOLD}│   canton devrel installed successfully! │${NC}"
echo -e "${GREEN}${BOLD}└─────────────────────────────────────────┘${NC}"
echo ""
echo "  Reload your shell, then run:"
echo ""
echo -e "    ${BOLD}canton devrel start${NC}"
echo ""
echo "  Or reload now:"
case "$SHELL_NAME" in
  zsh)  echo "    source ~/.zshrc" ;;
  bash) echo "    source ~/.bashrc" ;;
  *)    echo "    (reload your shell)" ;;
esac
echo ""
echo "  Full command reference: canton devrel --help"
echo ""