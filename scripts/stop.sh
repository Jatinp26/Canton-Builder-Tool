#!/usr/bin/env bash
# canton devrel stop — gracefully stops all LocalNet containers
set -euo pipefail

DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"

print_header "Canton DevRel — Stopping LocalNet"

print_step "Stopping containers..."
"${COMPOSE_CMD[@]}" stop

echo ""
print_ok "LocalNet stopped. Data volumes are preserved."
echo "  Resume with: canton devrel start"
echo "  Full reset:  canton devrel reset"
echo ""
