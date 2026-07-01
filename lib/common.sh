# lib/common.sh — shared helpers for install.sh and uninstall.sh

append_once() {
    local line="$1" file="$2"
    grep -qxF "$line" "$file" 2>/dev/null || printf '\n%s\n' "$line" >> "$file"
}
