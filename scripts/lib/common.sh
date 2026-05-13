#!/usr/bin/env bash
# canton-devrel: shared helpers

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"
  echo ""
}

print_step() {
  echo -e "${BLUE}▶  $1${NC}"
}

print_ok() {
  echo -e "${GREEN}✓  $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠  $1${NC}"
}

print_error() {
  echo -e "${RED}✗  $1${NC}"
}

# Resolve compose project dir
# BASH_SOURCE[0] = scripts/lib/common.sh → ../.. = repo root
# Only set if not already defined by the calling script
if [ -z "${DEVREL_DIR:-}" ]; then
  DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
COMPOSE_CMD=(docker compose
  --project-directory "$DEVREL_DIR/docker"
  --env-file "$DEVREL_DIR/.env"
)

# Get admin token for a given Keycloak realm and client
# Usage: get_admin_token <realm> <client_id> <client_secret>
get_admin_token() {
  local realm="$1"
  local client_id="$2"
  local client_secret="$3"

  curl -fsS \
    "http://keycloak.localhost:8082/realms/${realm}/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "client_id=${client_id}" \
    -d "client_secret=${client_secret}" \
    -d 'grant_type=client_credentials' \
    -d 'scope=openid' | jq -r .access_token
}

# Known client credentials (from Keycloak realm configs)
PROVIDER_CLIENT_ID="app-provider-validator"
PROVIDER_CLIENT_SECRET="6m12QyyGl81d9nABWQXMycZdXho6ejEX"
PROVIDER_REALM="AppProvider"
PROVIDER_JSON_API="http://localhost:3975"

USER_CLIENT_ID="app-user-validator"
USER_CLIENT_SECRET="6m12QyyGl81d9nABWQXMycZdXho6ejEX"
USER_REALM="AppUser"
USER_JSON_API="http://localhost:2975"