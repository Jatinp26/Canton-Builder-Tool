#!/usr/bin/env bash
# canton devrel deploy <path/to/your.dar>
# Uploads a pre-built DAR to App Provider and App User participants
# Uses shared-secret auth (default for official Splice LocalNet)
set -euo pipefail

DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"

# ─── Args ─────────────────────────────────────────────────────────────────────

if [ $# -lt 1 ]; then
  echo ""
  print_error "Usage: canton devrel deploy <path/to/your-project.dar>"
  echo ""
  echo "  Example:"
  echo "    canton devrel deploy ./my-app/.daml/dist/my-app-0.0.1.dar"
  echo ""
  exit 1
fi

DAR_PATH="$1"

if [ ! -f "$DAR_PATH" ]; then
  print_error "DAR file not found: $DAR_PATH"
  exit 1
fi

DAR_FILENAME=$(basename "$DAR_PATH")
DAR_SIZE=$(du -sh "$DAR_PATH" | cut -f1)

print_header "Canton DevRel — Deploying DAR"
echo "  File: $DAR_FILENAME ($DAR_SIZE)"
echo ""

# ─── Check validators are up ──────────────────────────────────────────────────

print_step "Checking validators are reachable..."

for port in 3903 2903; do
  if ! curl -fs "http://localhost:${port}/api/validator/readyz" &>/dev/null; then
    print_error "Validator on port $port is not responding."
    echo "  Is LocalNet running? Try: canton devrel start"
    exit 1
  fi
done
print_ok "Validators reachable"

# ─── Auth token ───────────────────────────────────────────────────────────────
# The official Splice LocalNet uses shared-secret auth by default.
# The shared secret is "unsafe" — the token IS the secret, passed as Bearer.
# This is read from the bundle's common.env SPLICE_APP_UI_UNSAFE_SECRET variable.

BUNDLE_COMMON_ENV="$LOCALNET_DIR/env/common.env"
if [ -f "$BUNDLE_COMMON_ENV" ]; then
  SHARED_SECRET=$(grep 'SPLICE_APP_UI_UNSAFE_SECRET' "$BUNDLE_COMMON_ENV" \
    | sed 's/.*:-\(.*\)}/\1/' | tr -d '"' | tr -d "'" || echo "unsafe")
else
  SHARED_SECRET="unsafe"
fi

# The token is the shared secret itself — no JWT generation needed
TOKEN="$SHARED_SECRET"

print_step "Using shared-secret auth (token: ${TOKEN})"

# ─── Upload to App Provider ───────────────────────────────────────────────────

echo ""
print_step "Uploading to App Provider participant (port 3975)..."

upload_dar() {
  local name="$1"
  local port="$2"

  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "http://localhost:${port}/v2/packages" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@${DAR_PATH}")

  HTTP_CODE=$(echo "$RESPONSE" | awk 'END{print}')
  BODY=$(echo "$RESPONSE" | awk 'NR>1{print prev} {prev=$0}')

  case "$HTTP_CODE" in
    200|204)
      print_ok "Uploaded to $name" ;;
    409)
      print_ok "Already uploaded to $name (package already exists — that's fine)" ;;
    401)
      print_error "Auth failed on $name (HTTP 401)."
      echo ""
      echo "  The shared secret may differ from 'unsafe' in your bundle."
      echo "  Check: cat ~/.canton-devrel/bundle/splice-node/docker-compose/localnet/env/common.env | grep UNSAFE"
      exit 1 ;;
    *)
      print_error "Upload failed on $name (HTTP $HTTP_CODE)"
      echo "  Response: $BODY"
      exit 1 ;;
  esac
}

upload_dar "App Provider" 3975
upload_dar "App User"     2975

# ─── Print package ID ─────────────────────────────────────────────────────────

echo ""
print_step "Resolving package ID..."

if command -v dpm &>/dev/null; then
  PACKAGE_ID=$(dpm damlc inspect-dar "$DAR_PATH" 2>/dev/null | \
    grep -v "dalf" | grep -v "^$" | tail -1 | awk '{print $2}' | tr -d '"' || echo "")

  if [ -n "$PACKAGE_ID" ]; then
    echo ""
    print_ok "Package ID: $PACKAGE_ID"
    echo ""
    echo "  Template ID format for API calls:"
    echo "    ${PACKAGE_ID}:<ModuleName>:<TemplateName>"
  fi
else
  print_warning "dpm not found — install dpm to get your package ID automatically."
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}  ✓ DAR deployed successfully to LocalNet!${NC}"
echo ""
echo "  App Provider JSON API:  http://localhost:3975"
echo "  App User JSON API:      http://localhost:2975"
echo "  App Provider Wallet:    http://wallet.localhost:3000"
echo ""
echo "  Auth token for API calls: Bearer $TOKEN"
echo ""