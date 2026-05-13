#!/usr/bin/env bash
# canton devrel deploy <path/to/your.dar>
# Uploads a pre-built DAR file to App Provider and App User participants
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

# ─── Get auth tokens ──────────────────────────────────────────────────────────

print_step "Getting admin tokens from Keycloak..."

PROVIDER_TOKEN=$(get_admin_token "$PROVIDER_REALM" "$PROVIDER_CLIENT_ID" "$PROVIDER_CLIENT_SECRET") || {
  print_error "Failed to get App Provider token. Is Keycloak running?"
  exit 1
}
print_ok "App Provider token acquired"

USER_TOKEN=$(get_admin_token "$USER_REALM" "$USER_CLIENT_ID" "$USER_CLIENT_SECRET") || {
  print_error "Failed to get App User token. Is Keycloak running?"
  exit 1
}
print_ok "App User token acquired"

# ─── Upload to App Provider ───────────────────────────────────────────────────

echo ""
print_step "Uploading to App Provider participant (port 3975)..."

PROVIDER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${PROVIDER_JSON_API}/v2/packages" \
  -H "Authorization: Bearer $PROVIDER_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@${DAR_PATH}")

PROVIDER_HTTP_CODE=$(echo "$PROVIDER_RESPONSE" | tail -n1)
PROVIDER_BODY=$(echo "$PROVIDER_RESPONSE" | head -n-1)

case "$PROVIDER_HTTP_CODE" in
  200|204)
    print_ok "Uploaded to App Provider" ;;
  409)
    print_ok "Already uploaded to App Provider (package already exists — that's fine)" ;;
  401)
    print_error "Auth failed on App Provider. Token may have expired. Try again."
    exit 1 ;;
  *)
    print_error "Upload failed on App Provider (HTTP $PROVIDER_HTTP_CODE)"
    echo "  Response: $PROVIDER_BODY"
    exit 1 ;;
esac

# ─── Upload to App User ───────────────────────────────────────────────────────

print_step "Uploading to App User participant (port 2975)..."

USER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${USER_JSON_API}/v2/packages" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@${DAR_PATH}")

USER_HTTP_CODE=$(echo "$USER_RESPONSE" | tail -n1)
USER_BODY=$(echo "$USER_RESPONSE" | head -n-1)

case "$USER_HTTP_CODE" in
  200|204)
    print_ok "Uploaded to App User" ;;
  409)
    print_ok "Already uploaded to App User (package already exists — that's fine)" ;;
  401)
    print_error "Auth failed on App User. Token may have expired. Try again."
    exit 1 ;;
  *)
    print_error "Upload failed on App User (HTTP $USER_HTTP_CODE)"
    echo "  Response: $USER_BODY"
    exit 1 ;;
esac

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
    echo "  Use this in your API calls:"
    echo "    Template ID format: ${PACKAGE_ID}:<ModuleName>:<TemplateName>"
  fi
else
  print_warning "dpm not found — skipping package ID resolution."
  echo "  Install dpm to get your package ID automatically."
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}  ✓ DAR deployed successfully!${NC}"
echo ""
echo "  Your contracts are live on LocalNet."
echo "  Wallet:  http://wallet.localhost:3000  (app-provider / abc123)"
echo "  API:     http://localhost:3975  (App Provider JSON Ledger API)"
echo ""