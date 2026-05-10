#!/usr/bin/env bash
# canton devrel status — shows health of all services + port reference
set -euo pipefail

DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"

print_header "Canton DevRel — Network Status"

check_http() {
  local label="$1"
  local url="$2"
  local extra="${3:-}"
  printf "  %-32s" "$label"
  if curl -fs "$url" &>/dev/null; then
    echo -e "${GREEN}● UP${NC}   ${extra}"
  else
    echo -e "${RED}● DOWN${NC} ${extra}"
  fi
}

echo -e "  ${BOLD}Validators${NC}"
check_http "Super Validator"          "http://localhost:4903/api/validator/readyz" "(port 4903)"
check_http "App Provider Validator"   "http://localhost:3903/api/validator/readyz" "(port 3903)"
check_http "App User Validator"       "http://localhost:2903/api/validator/readyz" "(port 2903)"

echo ""
echo -e "  ${BOLD}JSON Ledger API${NC}"
check_http "App Provider JSON API"    "http://localhost:3975/readyz" "(http://localhost:3975)"
check_http "App User JSON API"        "http://localhost:2975/readyz" "(http://localhost:2975)"
check_http "SV JSON API"              "http://localhost:4975/readyz" "(http://localhost:4975)"

echo ""
echo -e "  ${BOLD}UIs${NC}"
check_http "App User Wallet"          "http://localhost:2000"        "(http://wallet.localhost:2000)"
check_http "App Provider Wallet"      "http://localhost:3000"        "(http://wallet.localhost:3000)"
check_http "Scan / SV UI"             "http://localhost:4000"        "(http://scan.localhost:4000)"
check_http "Keycloak"                 "http://localhost:8082"        "(http://keycloak.localhost:8082)"

echo ""
echo -e "  ${BOLD}Docker containers${NC}"
"${COMPOSE_CMD[@]}" ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null | \
  sed 's/^/  /' || echo "  (docker compose not running)"

echo ""
echo -e "  ${BOLD}Port Reference${NC}"
echo "  ─────────────────────────────────────────────"
printf "  %-35s %s\n" "App Provider Ledger API (gRPC)"  "localhost:3901"
printf "  %-35s %s\n" "App User Ledger API (gRPC)"      "localhost:2901"
printf "  %-35s %s\n" "App Provider JSON API"            "localhost:3975"
printf "  %-35s %s\n" "App User JSON API"                "localhost:2975"
printf "  %-35s %s\n" "App Provider Validator API"       "localhost:3903"
printf "  %-35s %s\n" "App User Validator API"           "localhost:2903"
printf "  %-35s %s\n" "PostgreSQL"                       "localhost:5432"
printf "  %-35s %s\n" "Keycloak"                         "localhost:8082 (keycloak.localhost:8082)"
echo "  ─────────────────────────────────────────────"
echo ""
echo "  Wallet login:  app-user / abc123  |  app-provider / abc123"
echo ""
