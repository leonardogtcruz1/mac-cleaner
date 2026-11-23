#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH_DIR="${TMPDIR:-/tmp}/mac-cleaner-build"
cd "$ROOT_DIR"

echo "Compilando MacCleaner em modo release..."
swift build -c release --product MacCleaner --scratch-path "$SCRATCH_DIR"

BIN_DIR="$(swift build -c release --product MacCleaner --show-bin-path --scratch-path "$SCRATCH_DIR")"
BINARY_PATH="$BIN_DIR/MacCleaner"

if [[ ! -x "$BINARY_PATH" ]]; then
    echo "Erro: binário não encontrado em $BINARY_PATH" >&2
    exit 1
fi

STAGE_APP="$SCRATCH_DIR/MacCleaner.app"
APP_DIR="$ROOT_DIR/build/MacCleaner.app"

rm -rf "$STAGE_APP"
mkdir -p "$STAGE_APP/Contents/MacOS" "$STAGE_APP/Contents/Resources"

cp "$BINARY_PATH" "$STAGE_APP/Contents/MacOS/MacCleaner"
chmod +x "$STAGE_APP/Contents/MacOS/MacCleaner"

cat > "$STAGE_APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>pt_BR</string>
    <key>CFBundleExecutable</key>
    <string>MacCleaner</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.MacCleaner</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MacCleaner</string>
    <key>CFBundleDisplayName</key>
    <string>MacCleaner</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <string>true</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "Assinando bundle em staging (ad-hoc)..."
xattr -cr "$STAGE_APP"
codesign --force --deep --sign - "$STAGE_APP"
codesign --verify "$STAGE_APP"

rm -rf "$APP_DIR"
mkdir -p "$(dirname "$APP_DIR")"
ditto --norsrc "$STAGE_APP" "$APP_DIR"
xattr -cr "$APP_DIR" 2>/dev/null || true

if codesign --verify "$APP_DIR" 2>/dev/null; then
    echo "App gerado e verificado com sucesso em: $APP_DIR"
else
    echo "Tentando assinar novamente em $APP_DIR..."
    xattr -cr "$APP_DIR" 2>/dev/null || true
    if codesign --force --deep --sign - "$APP_DIR" 2>/dev/null && codesign --verify "$APP_DIR" 2>/dev/null; then
        echo "App gerado e assinado em: $APP_DIR"
    else
        echo "App copiado para $APP_DIR (cópia assinada e verificada também disponível em $STAGE_APP)."
    fi
fi
