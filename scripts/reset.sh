#!/usr/bin/env bash
# canton devrel reset — wipes all containers, volumes, data. Full clean slate.
set -euo pipefail

DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"

print_header "Canton DevRel — Full Reset"

print_warning "This will DELETE all LocalNet data:"
echo "  • All ledger state (contracts, transactions)"
echo "  • All party registrations"
echo "  • All Canton Coin balances"
echo "  • All uploaded DARs"
echo "  • All PostgreSQL data"
echo ""
read -rp "  Are you sure? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
  echo "  Aborted. Nothing was changed."
  exit 0
fi

echo ""
print_step "Stopping containers..."
"${COMPOSE_CMD[@]}" down --remove-orphans 2>/dev/null || true

print_step "Removing volumes..."
"${COMPOSE_CMD[@]}" down -v 2>/dev/null || true

print_step "Pruning dangling images (optional)..."
docker image prune -f &>/dev/null || true

echo ""
print_ok "Reset complete. LocalNet data has been wiped."
echo "  Start fresh with: canton devrel start"
echo ""
