#!/usr/bin/env bash

set -euo pipefail
DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"
print_header "Canton DevRel Tool Starting LocalNet"

if ! docker info &>/dev/null; then
  print_error "Docker is not running. Start Docker Desktop and try again."
  exit 1
fi
if ! docker compose version &>/dev/null; then
  print_error "Docker Compose v2 not found. Update Docker Desktop to get it."
  exit 1
fi

DOCKER_MEMORY_BYTES=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
DOCKER_MEMORY_GB=$(( DOCKER_MEMORY_BYTES / 1024 / 1024 / 1024 ))
if [ "$DOCKER_MEMORY_GB" -lt 7 ]; then
  print_warning "Docker has ~${DOCKER_MEMORY_GB}GB memory. LocalNet needs at least 8GB."
  print_warning "Go to Docker Desktop Settings and Under Resources, Check Memory and increase it."
  echo ""
  read -rp "  Continue anyway? [y/N] " confirm
  confirm_lower="$(echo "$confirm" | tr '[:upper:]' '[:lower:]')"
  [ "$confirm_lower" = "y" ] || { echo "Aborted."; exit 1; }
fi

MISSING_HOSTS=()
for domain in wallet.localhost scan.localhost sv.localhost; do
  grep -q "$domain" /etc/hosts 2>/dev/null || MISSING_HOSTS+=("$domain")
done

if [ ${#MISSING_HOSTS[@]} -gt 0 ]; then
  print_warning "Some *.localhost domains are not in /etc/hosts:"
  print_warning "  ${MISSING_HOSTS[*]}"
  echo ""
  echo "  Fix (requires sudo):"
  echo "    echo '127.0.0.1  wallet.localhost scan.localhost sv.localhost' | sudo tee -a /etc/hosts"
  echo ""
  read -rp "  Fix it automatically now? [y/N] " fix_hosts
  fix_hosts_lower="$(echo "$fix_hosts" | tr '[:upper:]' '[:lower:]')"
  if [ "$fix_hosts_lower" = "y" ]; then
    echo "127.0.0.1  wallet.localhost scan.localhost sv.localhost" | sudo tee -a /etc/hosts > /dev/null
    print_ok "Added to /etc/hosts."
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
      print_warning "WSL detected: /etc/hosts may reset on reboot. If domains stop resolving, re-run canton devrel start."
    fi
  fi
fi

BUNDLE_EXTRACT_DIR="${BUNDLE_DIR:-$HOME/.canton-devrel/bundle}"
LOCALNET_COMPOSE="$BUNDLE_EXTRACT_DIR/splice-node/docker-compose/localnet/compose.yaml"
if [ ! -f "$LOCALNET_COMPOSE" ]; then
  print_step "Downloading Splice LocalNet bundle v${IMAGE_TAG}..."
  echo "  This is a one-time download (~500MB). It will be cached for future runs."
  echo ""
  mkdir -p "$BUNDLE_EXTRACT_DIR"
  TARBALL_URLS=(
    "https://github.com/digital-asset/decentralized-canton-sync/releases/download/v${IMAGE_TAG}/${IMAGE_TAG}_splice-node.tar.gz"
  )
  TARBALL_PATH="$BUNDLE_EXTRACT_DIR/${IMAGE_TAG}_splice-node.tar.gz"
  DOWNLOADED=0
  for TARBALL_URL in "${TARBALL_URLS[@]}"; do
    echo "  Trying: $TARBALL_URL"
    curl -fsSL --location --progress-bar "$TARBALL_URL" -o "$TARBALL_PATH" 2>/dev/null && {
      if [ -s "$TARBALL_PATH" ] && (file "$TARBALL_PATH" 2>/dev/null | grep -q "gzip\|tar\|compressed" || python3 -c "import sys; d=open('$TARBALL_PATH','rb').read(2); sys.exit(0 if d==b'\x1f\x8b' else 1)" 2>/dev/null); then
        DOWNLOADED=1
        break
      else
        print_warning "Downloaded file is not a valid tarball trying next URL..."
        rm -f "$TARBALL_PATH"
      fi
    }
  done
  if [ $DOWNLOADED -eq 0 ]; then
    print_error "Could not download the Splice LocalNet bundle."
    echo ""
    echo "  Download it manually from:"
    echo "    https://github.com/digital-asset/decentralized-canton-sync/releases/tag/v${IMAGE_TAG}"
    echo ""
    echo "  Then place the file at:"
    echo "    $TARBALL_PATH"
    echo ""
    echo "  And re-run: canton devrel start"
    exit 1
  fi
  print_step "Extracting bundle..."
  tar -xzf "$TARBALL_PATH" -C "$BUNDLE_EXTRACT_DIR"
  rm -f "$TARBALL_PATH"
  print_ok "Bundle ready at $BUNDLE_EXTRACT_DIR"
else
  print_ok "Bundle already downloaded (v${IMAGE_TAG})"
fi

print_step "Pulling Canton Network images (first run: ~3-5 min, then cached)..."
"${COMPOSE_CMD[@]}" pull --quiet 2>/dev/null || {
  print_warning "Silent pull failed — retrying with output..."
  "${COMPOSE_CMD[@]}" pull
}
print_step "Starting LocalNet..."
"${COMPOSE_CMD[@]}" up -d --remove-orphans
print_step "Waiting for validators to be ready..."
echo "  This takes ~5 minutes on first run. Hang tight."
echo ""

wait_for_validator() {
  local name="$1"
  local port="$2"
  local max_attempts=60
  local attempt=0
  printf "  %-20s" "$name"
  while [ $attempt -lt $max_attempts ]; do
    if curl -fs "http://localhost:${port}/api/validator/readyz" &>/dev/null; then
      print_ok "ready"
      return 0
    fi
    printf "."
    sleep 5
    (( attempt++ ))
  done
  echo ""
  print_error "timed out after $((max_attempts * 5))s"
  return 1
}

FAILED=0
wait_for_validator "Super Validator"  4903 || FAILED=1
wait_for_validator "App Provider"     3903 || FAILED=1
wait_for_validator "App User"         2903 || FAILED=1
echo ""

if [ $FAILED -eq 1 ]; then
  print_error "One or more validators failed to start."
  echo ""
  echo "  Check logs: canton devrel logs"
  echo "  Reset: canton devrel reset && canton devrel start"
  exit 1
fi

print_header "Yayy! LocalNet is up!"
echo ""
echo "  Wallet UIs:"
echo "    App User     →  http://wallet.localhost:2000  (login: app-user)"
echo "    App Provider →  http://wallet.localhost:3000  (login: app-provider)"
echo "    Scan         →  http://scan.localhost:4000"
echo "    SV UI        →  http://sv.localhost:4000"
echo ""
echo "  JSON Ledger API:"
echo "    App Provider →  http://localhost:3975"
echo "    App User     →  http://localhost:2975"
echo ""
echo "  Deploy your DAR:  canton devrel deploy ./your-project.dar"
echo "  Check status:     canton devrel status"
echo "  Stop:             canton devrel stop"
echo ""