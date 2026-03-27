#!/bin/bash
# ViMDav - Register Cmd+Ctrl+I global shortcut (macOS)
# (Insert key is absent on most Mac keyboards; Cmd+Ctrl+I is the equivalent)
EDITOR_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_SCRIPT="$EDITOR_DIR/run.sh"

if [ ! -f "$RUN_SCRIPT" ]; then
  echo "run.sh not found at: $RUN_SCRIPT"
  exit 1
fi
chmod +x "$RUN_SCRIPT"

# Create a wrapper app using Automator-style AppleScript app
APP_DIR="$HOME/Applications/ViMDav.app/Contents/MacOS"
mkdir -p "$APP_DIR"
cat > "$APP_DIR/ViMDav" << EOF
#!/bin/bash
exec "$RUN_SCRIPT" "\$@"
EOF
chmod +x "$APP_DIR/ViMDav"

cat > "$HOME/Applications/ViMDav.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>ViMDav</string>
  <key>CFBundleIdentifier</key><string>com.vimdav.editor</string>
  <key>CFBundleName</key><string>ViMDav</string>
  <key>CFBundleDocumentTypes</key><array>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array><string>txt</string><string>lisp</string><string>md</string></array>
      <key>CFBundleTypeName</key><string>Text File</string>
      <key>CFBundleTypeRole</key><string>Editor</string>
    </dict>
  </array>
</dict></plist>
EOF

echo "ViMDav.app created in ~/Applications."
echo ""
echo "To set global shortcut (Cmd+Ctrl+I):"
echo "  1. Open System Preferences > Keyboard > Shortcuts > App Shortcuts"
echo "  2. Add shortcut for 'ViMDav' with Command+Control+I"
echo ""
echo "Or use Automator to create a Quick Action with the keyboard shortcut."
