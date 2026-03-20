#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Sierra.xcodeproj"
SCHEME="Sierra"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "❌ xcodebuild not found. Install Xcode first."
  exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "❌ Could not find Sierra.xcodeproj at: $PROJECT_PATH"
  exit 1
fi

echo "Sierra bootstrap"
echo "This will configure Mapbox package download auth in ~/.netrc and resolve SPM dependencies."
echo

read -r -s -p "Enter MAPBOX_DOWNLOADS_TOKEN (sk.*): " MAPBOX_TOKEN
echo

if [[ -z "${MAPBOX_TOKEN}" ]]; then
  echo "❌ Token cannot be empty."
  exit 1
fi

if [[ "$MAPBOX_TOKEN" != sk.* ]]; then
  echo "⚠️ Token does not start with 'sk.'. Double-check you entered the Downloads token, not the public pk token."
fi

NETRC_PATH="$HOME/.netrc"
TMP_NETRC="$(mktemp)"

if [[ -f "$NETRC_PATH" ]]; then
  cp "$NETRC_PATH" "$TMP_NETRC"
else
  : > "$TMP_NETRC"
fi

# Remove existing mapbox entries, if any, then append fresh values.
awk '
  BEGIN { skip = 0 }
  /^machine[[:space:]]+api\.mapbox\.com$/ { skip = 1; next }
  /^machine[[:space:]]+downloads\.mapbox\.com$/ { skip = 1; next }
  /^machine[[:space:]]+/ { skip = 0 }
  skip == 0 { print }
' "$TMP_NETRC" > "${TMP_NETRC}.clean"

cat >> "${TMP_NETRC}.clean" <<EOF
machine api.mapbox.com
  login mapbox
  password ${MAPBOX_TOKEN}
machine downloads.mapbox.com
  login mapbox
  password ${MAPBOX_TOKEN}
EOF

mv "${TMP_NETRC}.clean" "$NETRC_PATH"
chmod 600 "$NETRC_PATH"
rm -f "$TMP_NETRC"

echo "✅ ~/.netrc updated with Mapbox credentials."
echo "🔄 Resolving Swift package dependencies..."

xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME"

echo
echo "✅ Bootstrap complete."
echo "Next: open Sierra.xcodeproj in Xcode and build the Sierra scheme."
