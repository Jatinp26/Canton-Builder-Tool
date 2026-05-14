#!/usr/bin/env bash

set -euo pipefail
DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"
print_header "Canton builder Full Reset"
print_warning "This will DELETE all LocalNet data:"
echo "  • All ledger state (contracts, transactions)"
echo "  • All party registrations"
echo "  • All Canton Coin balances"
echo "  • All uploaded DARs"
echo "  • All PostgreSQL volumes"
echo ""
read -rp "  Are you sure? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
  echo "  Aborted. Nothing was changed."
  exit 0
fi

echo ""
print_step "Stopping containers and removing volumes..."
docker compose \
  --env-file "$LOCALNET_DIR/compose.env" \
  --env-file "$LOCALNET_DIR/env/common.env" \
  -f "$LOCALNET_DIR/compose.yaml" \
  -f "$LOCALNET_DIR/resource-constraints.yaml" \
  --profile sv --profile app-provider --profile app-user \
  down -v 2>/dev/null || true

echo ""
print_ok "Reset complete. All data wiped."
echo "  Start fresh: canton builder start"
echo ""