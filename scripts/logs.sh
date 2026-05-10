#!/usr/bin/env bash
# canton devrel logs [service] — tail container logs
# Usage:
#   canton devrel logs              # all services
#   canton devrel logs canton       # just the canton node
#   canton devrel logs splice       # just the splice/validator service
#   canton devrel logs keycloak     # just keycloak
set -euo pipefail

DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"

SERVICE="${1:-}"

if [ -n "$SERVICE" ]; then
  echo ""
  print_step "Tailing logs for: $SERVICE (Ctrl+C to stop)"
  echo ""
  "${COMPOSE_CMD[@]}" logs -f --tail=50 "$SERVICE"
else
  echo ""
  print_step "Tailing all logs (Ctrl+C to stop)"
  echo "  Tip: filter to one service with: canton devrel logs <service>"
  echo "  Services: canton, splice, postgres, keycloak, json-api-app-provider, json-api-app-user"
  echo ""
  "${COMPOSE_CMD[@]}" logs -f --tail=30
fi
