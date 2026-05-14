#!/usr/bin/env bash
set -euo pipefail
DEVREL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DEVREL_DIR/scripts/lib/common.sh"

if [ $# -lt 1 ]; then
  echo ""
  print_error "Usage: canton builder deploy <path/to/your-project.dar>"
  echo ""
  echo "  Example:"
  echo "    canton builder deploy ./my-app/.daml/dist/my-app-0.0.1.dar"
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
print_header "Deploying DAR"
echo "  File: $DAR_FILENAME ($DAR_SIZE)"
echo ""

print_step "Checking validators are reachable..."
for port in 3903 2903; do
  if ! curl -fs "http://localhost:${port}/api/validator/readyz" &>/dev/null; then
    print_error "Validator on port $port is not responding."
    echo "  Is LocalNet running? Try: canton builder start"
    exit 1
  fi
done
print_ok "Validators reachable"

BUNDLE_COMMON_ENV="$LOCALNET_DIR/env/common.env"
SECRET="unsafe"
if [ -f "$BUNDLE_COMMON_ENV" ]; then
  PARSED=$(grep 'SPLICE_APP_UI_UNSAFE_SECRET' "$BUNDLE_COMMON_ENV" | \
    sed 's/.*:-\(.*\)}/\1/' | tr -d '"' | tr -d "'" | tr -d ' ')
  [ -n "$PARSED" ] && SECRET="$PARSED"
fi

b64url() {
  printf '%s' "$1" | base64 | tr '+/' '-_' | tr -d '=' | tr -d '\n'
}
make_jwt() {
  local user="$1"
  local audience="$2"
  local exp
  exp=$(( $(date +%s) + 86400 ))  
  local header
  header=$(b64url '{"alg":"HS256","typ":"JWT"}')
  local payload
  payload=$(b64url "{\"sub\":\"${user}\",\"aud\":\"${audience}\",\"exp\":${exp}}")
  local signing_input="${header}.${payload}"
  local sig
  sig=$(printf '%s' "$signing_input" | openssl dgst -sha256 -hmac "$SECRET" -binary | \
    base64 | tr '+/' '-_' | tr -d '=' | tr -d '\n')
  printf '%s' "${signing_input}.${sig}"
}
print_step "Generating JWT tokens (HS256, secret: ${SECRET})..."
PROVIDER_TOKEN=$(make_jwt "ledger-api-user" "https://canton.network.global")
USER_TOKEN=$(make_jwt "ledger-api-user" "https://canton.network.global")
print_ok "Yayy! Tokens generated"
upload_dar() {
  local name="$1"
  local port="$2"
  local token="$3"
  echo ""
  print_step "Uploading to ${name} (port ${port})..."
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "http://localhost:${port}/v2/packages" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@${DAR_PATH}")

  case "$HTTP_CODE" in
    200|204)
      print_ok "Uploaded to ${name}" ;;
    409)
      print_ok "Already uploaded to ${name} (package exists — that's fine)" ;;
    401)
      print_error "Auth failed on ${name} (HTTP 401)"
      echo "  JWT may be malformed. Check openssl is available: openssl version"
      exit 1 ;;
    *)
      print_error "Upload failed on ${name} (HTTP ${HTTP_CODE})"
      exit 1 ;;
  esac
}
upload_dar "App Provider" 3975 "$PROVIDER_TOKEN"
upload_dar "App User"     2975 "$USER_TOKEN"

echo ""
print_step "Resolving package ID..."

if command -v dpm &>/dev/null; then
  PACKAGE_ID=$(dpm damlc inspect-dar "$DAR_PATH" 2>/dev/null | \
    grep -v "dalf" | grep -v "^$" | \
    awk 'END{print}' | awk '{print $2}' | tr -d '"' || echo "")

  if [ -n "$PACKAGE_ID" ]; then
    echo ""
    print_ok "Package ID: $PACKAGE_ID"
    echo ""
    echo "  Template ID format for API calls:"
    echo "    ${PACKAGE_ID}:<ModuleName>:<TemplateName>"
    echo ""
    echo "  Example API call:"
    echo "    curl -X POST http://localhost:3975/v2/commands/submit-and-wait \\"
    echo "      -H \"Authorization: Bearer \$TOKEN\" \\"
    echo "      -H \"Content-Type: application/json\" \\"
    echo "      -d '{...}'"
  fi
else
  print_warning "dpm not found, install dpm to get your package ID automatically."
fi

echo ""
echo -e "${GREEN}${BOLD} DAR deployed successfully to LocalNet!${NC}"
echo ""
echo "  Your token for API calls (valid 24h):"
echo "    $PROVIDER_TOKEN"
echo ""
echo "  App Provider JSON API:  http://localhost:3975"
echo "  App User JSON API:      http://localhost:2975"
echo ""