#!/usr/bin/env bash

set -euo pipefail
DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"
print_header "Canton Builder Tool Network Status"
check_http() {
  local label="$1"
  local url="$2"
  local extra="${3:-}"
  printf "  %-34s" "$label"
  if curl -fs "$url" &>/dev/null; then
    echo -e "${GREEN}● UP${NC}   ${extra}"
  else
    echo -e "${RED}● DOWN${NC} ${extra}"
  fi
}

echo -e "  ${BOLD}Validators${NC}"
check_http "Super Validator"         "http://localhost:4903/api/validator/readyz" "(port 4903)"
check_http "App Provider Validator"  "http://localhost:3903/api/validator/readyz" "(port 3903)"
check_http "App User Validator"      "http://localhost:2903/api/validator/readyz" "(port 2903)"
echo ""
echo -e "  ${BOLD}JSON Ledger API${NC}"
check_http "App Provider JSON API"   "http://localhost:3975/readyz" "(http://localhost:3975)"
check_http "App User JSON API"       "http://localhost:2975/readyz" "(http://localhost:2975)"
check_http "SV JSON API"             "http://localhost:4975/readyz" "(http://localhost:4975)"

echo ""
echo -e "  ${BOLD}UIs${NC}"
check_http "App User Wallet"         "http://wallet.localhost:2000" "(http://wallet.localhost:2000)"
check_http "App Provider Wallet"     "http://wallet.localhost:3000" "(http://wallet.localhost:3000)"
check_http "Scan UI"                 "http://scan.localhost:4000"   "(http://scan.localhost:4000)"
check_http "SV UI"                   "http://sv.localhost:4000"     "(http://sv.localhost:4000)"

echo ""
echo -e "  ${BOLD}Running containers${NC}"
"${COMPOSE_CMD[@]}" ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null | sed 's/^/  /' \
  || echo "  (LocalNet not running)"

echo ""
echo -e "  ${BOLD}Port Reference${NC}"
echo "  ────────────────────────────────────────────────"
printf "  %-38s %s\n" "App Provider Ledger API (gRPC)"  "localhost:3901"
printf "  %-38s %s\n" "App User Ledger API (gRPC)"      "localhost:2901"
printf "  %-38s %s\n" "SV Ledger API (gRPC)"            "localhost:4901"
printf "  %-38s %s\n" "App Provider JSON API"            "localhost:3975"
printf "  %-38s %s\n" "App User JSON API"                "localhost:2975"
printf "  %-38s %s\n" "SV JSON API"                     "localhost:4975"
printf "  %-38s %s\n" "App Provider Validator API"       "localhost:3903"
printf "  %-38s %s\n" "App User Validator API"           "localhost:2903"
printf "  %-38s %s\n" "SV Validator API"                 "localhost:4903"
printf "  %-38s %s\n" "PostgreSQL"                       "localhost:5432"
echo "  ────────────────────────────────────────────────"
echo ""
echo "  Wallet login: app-user  |  app-provider  |  sv"
echo ""