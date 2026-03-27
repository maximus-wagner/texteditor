#!/bin/bash
# mac-hotkey.sh
# Sets up Cmd+Ctrl+E to open the text editor on macOS.
# Uses skhd (Simple Hotkey Daemon): brew install skhd
#
# Note: Mac keyboards do not have an Insert key.
# Default binding: Cmd+Ctrl+E

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RUN_SH="$PROJECT_DIR/run.sh"

# Install skhd if missing
if ! command -v skhd >/dev/null 2>&1; then
    echo "skhd not found. Installing via Homebrew..."
    if ! command -v brew >/dev/null 2>&1; then
        echo "ERROR: Homebrew not found."
        echo "Install from https://brew.sh/ first, then re-run this script."
        exit 1
    fi
    brew install skhd
fi

SKHD_RC="$HOME/.config/skhd/skhdrc"
mkdir -p "$(dirname "$SKHD_RC")"

if grep -qF "texteditor" "$SKHD_RC" 2>/dev/null; then
    echo "Hotkey already present in $SKHD_RC"
else
    printf '\n# texteditor - Cmd+Ctrl+E\ncmd + ctrl - e : cd "%s" && ./run.sh\n' "$PROJECT_DIR" >> "$SKHD_RC"
    echo "Added Cmd+Ctrl+E to $SKHD_RC"
fi

# Start / restart skhd service
skhd --start-service 2>/dev/null || { skhd -c "$SKHD_RC" & }

echo ""
echo "macOS hotkey ready: Cmd+Ctrl+E opens the text editor."
