# Installed to ~/.local/share/cp-tools/cp-tools.sh — do not source from checkout.

[[ -f "$HOME/.local/share/cp-tools/env.sh" ]] && source "$HOME/.local/share/cp-tools/env.sh"

cpcp() {
    if [[ -z "${CPP_TEMPLATE:-}" ]]; then
        echo "cpcp: CPP_TEMPLATE is not set" >&2
        return 1
    fi

    local edit=0
    case "${CPCP_EDIT:-}" in 1|yes|true|Y|y) edit=1 ;; esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--edit) edit=1; shift ;;
            -*) echo "Usage: cpcp [-e|--edit] <dest>" >&2; return 1 ;;
            *) break ;;
        esac
    done

    if [[ -z "$1" ]]; then
        echo "Usage: cpcp [-e|--edit] <dest>" >&2
        return 1
    fi

    local dest="$1"
    if [[ ! -f "$CPP_TEMPLATE" ]]; then
        echo "cpcp: CPP_TEMPLATE not found: $CPP_TEMPLATE" >&2
        return 1
    fi
    if [[ -e "$dest" ]]; then
        echo "cpcp: $dest already exists" >&2
        return 1
    fi
    cp "$CPP_TEMPLATE" "$dest"
    # Not `(( edit )) && ...`: as the last command that returns 1 when edit is 0.
    if (( edit )); then
        ${EDITOR:-vim} "$dest"
    fi
}

# Usage: [compile|run] [-S|--strict] [-D|--debug] [-F|--fast] <file.cpp> [extra g++ flags]
compile() {
    local strict=0 debug=0 fast=0
    case "${CPP_STRICT:-}" in 1|yes|true|Y|y) strict=1 ;; esac
    case "${CPP_DEBUG:-}" in 1|yes|true|Y|y) debug=1 ;; esac
    case "${CPP_FAST:-}" in 1|yes|true|Y|y) fast=1 ;; esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -S|--strict) strict=1; shift ;;
            -D|--debug)  debug=1; shift ;;
            -F|--fast)   fast=1; shift ;;
            *) break ;;
        esac
    done
    if [[ -z "$1" ]]; then
        echo "Usage: compile [-S|--strict] [-D|--debug] [-F|--fast] <file.cpp> [extra g++ flags]"
        return 1
    fi

    local src="$1" base="${1%.*}"
    shift

    local -a strict_flags=() debug_flags=() check_flags=()
    (( strict )) && strict_flags=(
        -Wshadow -Wconversion -Wsign-conversion
        -Wduplicated-cond -Wduplicated-branches -Wlogical-op
        -Wnull-dereference -Wvla
        -Wfloat-equal -Wcast-qual -Wcast-align -Wshift-overflow=2
    )
    (( debug )) && debug_flags=(-D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC)
    # The checks cost roughly 1.7x runtime, so -F drops them when a timing needs
    # to resemble the judge's.
    (( fast )) || check_flags=(
        -D_GLIBCXX_ASSERTIONS
        -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all
    )

    g++ -DLOCAL -std=c++17 -O2 -g \
        -Wall -Wextra -Wformat=2 -Wno-unused-variable -Wno-unused-parameter \
        "${check_flags[@]}" "${debug_flags[@]}" "${strict_flags[@]}" "$src" -o "$base" "$@" \
        || { echo "Compilation failed."; return 1; }
}

run() {
    if [[ -z "$1" ]]; then
        echo "Usage: run [-S|--strict] [-D|--debug] [-F|--fast] <file.cpp> [extra g++ flags]"
        return 1
    fi

    local -a a=("$@")
    local i=0
    while (( i < ${#a[@]} )); do
        case "${a[i]}" in
            -S|--strict|-D|--debug|-F|--fast) (( ++i )) ;;
            *) break ;;
        esac
    done
    local base="${a[i]%.*}"

    compile "$@" || return 1
    [[ "$base" != */* ]] && base="./$base"

    # Subshell so the cleanup trap dies with it. A trap set here would outlive the
    # function and fire on every later Ctrl-C in the interactive shell.
    ( trap 'rm -f "$base"' EXIT INT TERM; "$base" )
    local ec=$?
    echo
    return $ec
}

# stress-test.sh is installed next to this file; expose it like the other commands
# so it does not depend on ~/.local/bin being on PATH.
stress-test() {
    local script="${BASH_SOURCE[0]%/*}/stress-test.sh"
    if [[ ! -x "$script" ]]; then
        echo "stress-test: not found at $script — re-run cp-tools/install.sh" >&2
        return 1
    fi
    "$script" "$@"
}
