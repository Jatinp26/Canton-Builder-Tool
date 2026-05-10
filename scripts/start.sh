#!/usr/bin/env bash
# canton devrel start — boots Canton LocalNet
set -euo pipefail

DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"

# ─── Preflight checks ─────────────────────────────────────────────────────────

print_header "Canton DevRel — Starting LocalNet"

# Check Docker is running
if ! docker info &>/dev/null; then
  print_error "Docker is not running. Start Docker Desktop and try again."
  exit 1
fi

# Check Docker Compose v2
if ! docker compose version &>/dev/null; then
  print_error "Docker Compose v2 not found. Update Docker Desktop to get it."
  exit 1
fi

# Check memory allocation
DOCKER_MEMORY_BYTES=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
DOCKER_MEMORY_GB=$(echo "$DOCKER_MEMORY_BYTES / 1024 / 1024 / 1024" | bc 2>/dev/null || echo 0)
if [ "${DOCKER_MEMORY_GB}" -lt 7 ] 2>/dev/null; then
  print_warning "Docker has less than 8 GB of memory allocated (detected: ~${DOCKER_MEMORY_GB}GB)."
  print_warning "Services may crash. Go to Docker Desktop → Settings → Resources → Memory and set it to at least 8 GB."
  echo ""
  read -rp "  Continue anyway? [y/N] " confirm
  [[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 1; }
fi

# Check /etc/hosts for *.localhost entries
MISSING_HOSTS=()
for domain in wallet.localhost scan.localhost keycloak.localhost; do
  if ! grep -q "$domain" /etc/hosts 2>/dev/null; then
    MISSING_HOSTS+=("$domain")
  fi
done

if [ ${#MISSING_HOSTS[@]} -gt 0 ]; then
  print_warning "Some *.localhost domains are not in /etc/hosts."
  print_warning "The wallet and scan UIs may not load in your browser."
  echo ""
  echo "  Run this to fix it (requires sudo):"
  echo ""
  echo "    echo '127.0.0.1  wallet.localhost scan.localhost keycloak.localhost' | sudo tee -a /etc/hosts"
  echo ""
  read -rp "  Fix it automatically now? [y/N] " fix_hosts
  if [[ "${fix_hosts,,}" == "y" ]]; then
    echo "127.0.0.1  wallet.localhost scan.localhost keycloak.localhost" | sudo tee -a /etc/hosts > /dev/null
    print_ok "Added to /etc/hosts."
  fi
fi

# ─── Pull images ──────────────────────────────────────────────────────────────

print_step "Pulling Canton Network images (first run: ~3-5 min, then cached)..."
docker compose \
  --project-directory "$DEVREL_DIR/docker" \
  --env-file "$DEVREL_DIR/.env" \
  pull --quiet 2>/dev/null || {
    print_warning "Some images failed to pull quietly — retrying with output..."
    docker compose \
      --project-directory "$DEVREL_DIR/docker" \
      --env-file "$DEVREL_DIR/.env" \
      pull
  }

# ─── Start the stack ──────────────────────────────────────────────────────────

print_step "Starting LocalNet..."
docker compose \
  --project-directory "$DEVREL_DIR/docker" \
  --env-file "$DEVREL_DIR/.env" \
  up -d --remove-orphans

# ─── Wait for healthy validators ──────────────────────────────────────────────

print_step "Waiting for validators to be ready..."
echo "  This takes 2-4 minutes on first run. Hang tight."
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
    ((attempt++))
  done
  echo ""
  print_error "timed out after $((max_attempts * 5))s"
  return 1
}

FAILED=0
wait_for_validator "Super Validator"   4903 || FAILED=1
wait_for_validator "App Provider"      3903 || FAILED=1
wait_for_validator "App User"          2903 || FAILED=1

echo ""

if [ $FAILED -eq 1 ]; then
  print_error "One or more validators failed to start."
  echo ""
  echo "  Check logs with:  canton devrel logs"
  echo "  Reset and retry:  canton devrel reset && canton devrel start"
  exit 1
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

print_header "LocalNet is up! 🎉"
echo ""
echo "  Wallet UIs:"
echo "    App User     →  http://wallet.localhost:2000  (user: app-user / abc123)"
echo "    App Provider →  http://wallet.localhost:3000  (user: app-provider / abc123)"
echo "    Scan         →  http://scan.localhost:4000"
echo ""
echo "  JSON Ledger API:"
echo "    App Provider →  http://localhost:3975"
echo "    App User     →  http://localhost:2975"
echo ""
echo "  Keycloak:         http://keycloak.localhost:8082  (admin / admin)"
echo ""
echo "  Deploy your DAR:  canton devrel deploy ./your-project.dar"
echo "  Check status:     canton devrel status"
echo "  Stop:             canton devrel stop"
echo ""
