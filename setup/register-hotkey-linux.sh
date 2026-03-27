#!/bin/bash
# ViMDav - Register Super+Insert global hotkey (Linux)
EDITOR_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_SCRIPT="$EDITOR_DIR/run.sh"

if [ ! -f "$RUN_SCRIPT" ]; then
  echo "run.sh not found at: $RUN_SCRIPT"
  exit 1
fi
chmod +x "$RUN_SCRIPT"

# Method 1: xbindkeys (works on most DEs)
if command -v xbindkeys &>/dev/null || \
   (sudo apt-get install -y xbindkeys 2>/dev/null || \
    sudo pacman -S --noconfirm xbindkeys 2>/dev/null || \
    sudo dnf install -y xbindkeys 2>/dev/null); then
  BINDING="\"$RUN_SCRIPT\"\n  super + Insert"
  if ! grep -q "super + Insert" ~/.xbindkeysrc 2>/dev/null; then
    printf "\n# ViMDav\n$BINDING\n" >> ~/.xbindkeysrc
  fi
  xbindkeys --poll-rc 2>/dev/null || (pkill xbindkeys; xbindkeys)
  echo "Registered: Super+Insert -> ViMDav (via xbindkeys)"
fi

# Also register .desktop file
DESKTOP="$HOME/.local/share/applications/vimdav.desktop"
cat > "$DESKTOP" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ViMDav
Comment=Visual Modal Text Editor by David and Max
Exec=$RUN_SCRIPT %f
Icon=accessories-text-editor
Terminal=true
Categories=TextEditor;Development;
MimeType=text/plain;text/x-lisp;text/markdown;application/x-sh;
EOF
update-desktop-database ~/.local/share/applications/ 2>/dev/null
xdg-mime default vimdav.desktop text/plain 2>/dev/null
echo "Registered as default text editor."
