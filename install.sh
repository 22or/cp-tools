#!/usr/bin/env bash
# install.sh — install cp-tools shell helpers under ~/.local/share/cp-tools
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

append_once() {
    local line="$1" file="$2"
    grep -qxF "$line" "$file" 2>/dev/null || printf '\n%s\n' "$line" >> "$file"
}

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

read_env() {
    # shellcheck source=/dev/null
    [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
}

write_env() {
    local tpl="$1" edit="$2"
    {
        echo '# cp-tools user config'
        printf 'export CPP_TEMPLATE=%q\n' "$tpl"
        if (( edit )); then
            echo 'export CPCP_EDIT=1'
        fi
    } > "$ENV_FILE"
}

prompt_template_path() {
    local default="$ROOT/template.cpp" tpl

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
    printf '%s' "$tpl"
}

prompt_edit() {
    local current="$1" answer hint=

    [[ -n "$current" ]] && hint=" (currently $current)"
    read -r -p "Open new files in \$EDITOR after cpcp?${hint} [y/N]: " answer
    answer="${answer:-n}"
    case "$answer" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

configure_env() {
    local tpl edit=0 edit_current=off answer

    read_env
    tpl="${CPP_TEMPLATE:-}"
    case "${CPCP_EDIT:-}" in 1|yes|true|Y|y) edit=1; edit_current=on ;; esac

    if [[ -n "$tpl" ]]; then
        read -r -p "CPP_TEMPLATE is $tpl. Update? [y/N]: " answer
        answer="${answer:-n}"
        case "$answer" in
            [Yy]*) tpl="$(prompt_template_path)" ;;
        esac
    else
        tpl="$(prompt_template_path)"
    fi

    if prompt_edit "$edit_current"; then
        edit=1
    else
        edit=0
    fi

    write_env "$tpl" "$edit"
    echo "Wrote $ENV_FILE"
}

main() {
    [[ -f "$ROOT/cp-tools.sh" ]] || { echo "error: missing $ROOT/cp-tools.sh" >&2; exit 1; }
    [[ -f "$ROOT/stress-test.sh" ]] || { echo "error: missing $ROOT/stress-test.sh" >&2; exit 1; }

    mkdir -p "$INSTALL_DIR"
    cp -f "$ROOT/cp-tools.sh" "$INSTALL_DIR/cp-tools.sh"
    cp -f "$ROOT/stress-test.sh" "$INSTALL_DIR/stress-test.sh"
    chmod +x "$INSTALL_DIR/stress-test.sh"

    configure_env

    touch "$BASHRC"
    append_once "$SOURCE_LINE" "$BASHRC"

    echo "Installed cp-tools to $INSTALL_DIR"
    echo "Added source line to $BASHRC (if not already present)"
    echo "Open a new shell or run: source \"$BASHRC\""
}

main "$@"
