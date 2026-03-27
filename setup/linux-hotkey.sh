#!/bin/bash
# linux-hotkey.sh
# Sets up Super+Insert to open the text editor on Linux.
# Works with X11 via xbindkeys.
# For Wayland: configure the shortcut in your desktop environment settings.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RUN_SH="$PROJECT_DIR/run.sh"

# ---- X11 path: xbindkeys ----
if [ "${XDG_SESSION_TYPE}" != "wayland" ]; then
    if ! command -v xbindkeys >/dev/null 2>&1; then
        echo "xbindkeys not found. Install with:"
        echo "  Ubuntu/Debian:  sudo apt install xbindkeys"
        echo "  Fedora:         sudo dnf install xbindkeys"
        echo "  Arch:           sudo pacman -S xbindkeys"
        exit 1
    fi

    XBINDKEYS_RC="$HOME/.xbindkeysrc"

    if grep -qF "$RUN_SH" "$XBINDKEYS_RC" 2>/dev/null; then
        echo "Hotkey already present in $XBINDKEYS_RC"
    else
        printf '\n# texteditor - Super+Insert\n"%s &"\n  Super + Insert\n' "$RUN_SH" >> "$XBINDKEYS_RC"
        echo "Added Super+Insert to $XBINDKEYS_RC"
    fi

    pkill xbindkeys 2>/dev/null || true
    xbindkeys
    echo "Linux X11 hotkey ready: Super+Insert opens the text editor."

# ---- Wayland path: instructions ----
else
    echo "Wayland session detected. Configure your desktop environment shortcut manually:"
    echo ""
    echo "  GNOME:  Settings > Keyboard > Custom Shortcuts"
    echo "          Name: Text Editor"
    echo "          Command: $RUN_SH"
    echo "          Shortcut: Super+Insert"
    echo ""
    echo "  KDE:    System Settings > Shortcuts > Custom Shortcuts"
    echo "          Add script: $RUN_SH"
    echo "          Trigger: Super+Insert"
    echo ""
    echo "  Sway:   Add to ~/.config/sway/config:"
    echo "          bindsym Mod4+Insert exec $RUN_SH"
fi
