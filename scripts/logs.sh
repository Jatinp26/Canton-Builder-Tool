#!/usr/bin/env bash
set -euo pipefail
DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"
SERVICE="${1:-}"
echo ""
if [ -n "$SERVICE" ]; then
  print_step "Tailing logs for: $SERVICE (Ctrl+C to stop)"
  echo ""
  "${COMPOSE_CMD[@]}" logs -f --tail=50 "$SERVICE"
else
  print_step "Tailing all logs (Ctrl+C to stop)"
  echo "  Tip: filter to one service,  canton builder logs <service>"
  echo "  Common services: canton, splice, postgres, nginx"
  echo ""
  "${COMPOSE_CMD[@]}" logs -f --tail=30
fi