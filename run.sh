#!/bin/bash
set -e
cd "$(dirname "$0")"

# Find SBCL
SBCL=""
if command -v sbcl >/dev/null 2>&1; then
    SBCL=sbcl
else
    for path in \
        /usr/local/bin/sbcl \
        /opt/homebrew/bin/sbcl \
        /usr/bin/sbcl \
        "$HOME/.local/bin/sbcl"; do
        if [ -x "$path" ]; then
            SBCL="$path"
            break
        fi
    done
fi

if [ -z "$SBCL" ]; then
    echo "ERROR: SBCL not found."
    echo "Install with:"
    echo "  macOS:          brew install sbcl"
    echo "  Ubuntu/Debian:  sudo apt install sbcl"
    echo "  Fedora:         sudo dnf install sbcl"
    echo "  Arch:           sudo pacman -S sbcl"
    echo "  Or download from: https://www.sbcl.org/platform-table.html"
    exit 1
fi

exec "$SBCL" --dynamic-space-size 512 --non-interactive \
    --load src/main.lisp \
    --eval "(main:main)"
