#!/usr/bin/env bash
# uninstall.sh — remove ~/.local/share/cp-tools and its bashrc source line
set -euo pipefail

INSTALL_DIR="$HOME/.local/share/cp-tools"
BASHRC="$HOME/.bashrc"
SOURCE_LINE='[[ -f "$HOME/.local/share/cp-tools/cp-tools.sh" ]] && source "$HOME/.local/share/cp-tools/cp-tools.sh"'

main() {
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        echo "Removed $INSTALL_DIR"
    else
        echo "Nothing to remove at $INSTALL_DIR"
    fi

    if [[ -f "$BASHRC" ]]; then
        local tmp
        tmp=$(mktemp)
        grep -vxF "$SOURCE_LINE" "$BASHRC" > "$tmp" || true
        if ! cmp -s "$BASHRC" "$tmp"; then
            mv "$tmp" "$BASHRC"
            echo "Removed cp-tools source line from $BASHRC"
        else
            rm -f "$tmp"
            echo "No cp-tools source line in $BASHRC"
        fi
    fi
}

main "$@"
