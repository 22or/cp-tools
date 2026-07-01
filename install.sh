#!/usr/bin/env bash
# install.sh — install cp-tools shell helpers under ~/.local/share/cp-tools
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

INSTALL_DIR="$HOME/.local/share/cp-tools"
ENV_FILE="$INSTALL_DIR/env.sh"
BASHRC="$HOME/.bashrc"
SOURCE_LINE='[[ -f "$HOME/.local/share/cp-tools/cp-tools.sh" ]] && source "$HOME/.local/share/cp-tools/cp-tools.sh"'

expand_path() {
    local p="$1"
    [[ "$p" == "~" ]] && p="$HOME"
    [[ "$p" == "~/"* ]] && p="$HOME/${p:2}"
    printf '%s\n' "$p"
}

read_cpp_template() {
    # shellcheck source=/dev/null
    [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
    printf '%s' "${CPP_TEMPLATE:-}"
}

write_env_template() {
    local tpl="$1"
    {
        echo '# cp-tools user config — required for cpcp'
        printf 'export CPP_TEMPLATE=%q\n' "$tpl"
    } > "$ENV_FILE"
}

prompt_template() {
    local default="$ROOT/template.cpp" current answer tpl

    current="$(read_cpp_template)"
    if [[ -n "$current" ]]; then
        read -r -p "CPP_TEMPLATE is $current. Update? [y/N]: " answer
        answer="${answer:-n}"
        case "$answer" in
            [Yy]*) ;;
            *) echo "Keeping $ENV_FILE unchanged."; return 0 ;;
        esac
    fi

    if [[ -f "$default" ]]; then
        read -r -p "Path to your C++ template [$default]: " tpl
        tpl="${tpl:-$default}"
    else
        read -r -p "Path to your C++ template: " tpl
        while [[ -z "$tpl" ]]; do
            echo "  cpcp requires CPP_TEMPLATE — enter a path or Ctrl-C to abort."
            read -r -p "Path to your C++ template: " tpl
        done
    fi

    tpl="$(expand_path "$tpl")"
    if [[ ! -f "$tpl" ]]; then
        echo "error: template not found: $tpl" >&2
        exit 1
    fi

    write_env_template "$tpl"
    echo "Wrote CPP_TEMPLATE=$tpl to $ENV_FILE"
}

main() {
    [[ -f "$ROOT/cp-tools.sh" ]] || { echo "error: missing $ROOT/cp-tools.sh" >&2; exit 1; }

    mkdir -p "$INSTALL_DIR"
    cp -f "$ROOT/cp-tools.sh" "$INSTALL_DIR/cp-tools.sh"

    prompt_template

    touch "$BASHRC"
    append_once "$SOURCE_LINE" "$BASHRC"

    echo "Installed cp-tools to $INSTALL_DIR"
    echo "Added source line to $BASHRC (if not already present)"
    echo "Open a new shell or run: source \"$BASHRC\""
}

main "$@"
