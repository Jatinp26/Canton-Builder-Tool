#!/usr/bin/env bash
# canton devrel stop — stop LocalNet containers, preserve data
set -euo pipefail

DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"

print_header "Canton DevRel — Stopping LocalNet"
print_step "Stopping containers (data volumes preserved)..."

# Official stop command — note: down without -v keeps volumes
docker compose \
  --env-file "$LOCALNET_DIR/compose.env" \
  --env-file "$LOCALNET_DIR/env/common.env" \
  -f "$LOCALNET_DIR/compose.yaml" \
  -f "$LOCALNET_DIR/resource-constraints.yaml" \
  --profile sv --profile app-provider --profile app-user \
  down

echo ""
print_ok "LocalNet stopped. Data volumes preserved."
echo "  Resume:    canton devrel start"
echo "  Full wipe: canton devrel reset"
echo ""