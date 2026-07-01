# Installed to ~/.local/share/cp-tools/cp-tools.sh — do not source from checkout.

[[ -f "$HOME/.local/share/cp-tools/env.sh" ]] && source "$HOME/.local/share/cp-tools/env.sh"

cpcp() {
    if [[ -z "${CPP_TEMPLATE:-}" ]]; then
        echo "cpcp: CPP_TEMPLATE is not set" >&2
        return 1
    fi
    if [[ $# -ne 1 || "$1" == -* ]]; then
        echo "Usage: cpcp <dest>" >&2
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
}

# Usage: [compile|run] [-S|--strict] [-D|--debug] <file.cpp> [extra g++ flags]
compile() {
    local strict=0 debug=0
    case "${CPP_STRICT:-}" in 1|yes|true|Y|y) strict=1 ;; esac
    case "${CPP_DEBUG:-}" in 1|yes|true|Y|y) debug=1 ;; esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -S|--strict) strict=1; shift ;;
            -D|--debug)  debug=1; shift ;;
            *) break ;;
        esac
    done
    if [[ -z "$1" ]]; then
        echo "Usage: compile [-S|--strict] [-D|--debug] <file.cpp> [extra g++ flags]"
        return 1
    fi

    local src="$1" base="${1%.*}"
    shift

    local -a strict_flags=() debug_flags=()
    (( strict )) && strict_flags=(
        -Wshadow -Wconversion -Wsign-conversion
        -Wduplicated-cond -Wduplicated-branches -Wlogical-op
        -Wnull-dereference -Wvla
        -Wfloat-equal -Wcast-qual -Wcast-align -Wshift-overflow=2
    )
    (( debug )) && debug_flags=(-D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC)

    g++ -DLOCAL -D_GLIBCXX_ASSERTIONS -std=c++17 -O2 -g \
        -D_FORTIFY_SOURCE=2 -fstack-protector-strong \
        -Wall -Wextra -Wformat=2 -Wno-unused-variable -Wno-unused-parameter \
        -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all \
        "${debug_flags[@]}" "${strict_flags[@]}" "$src" -o "$base" "$@" \
        || { echo "Compilation failed."; return 1; }
}

run() {
    if [[ -z "$1" ]]; then
        echo "Usage: run [-S|--strict] [-D|--debug] <file.cpp> [extra g++ flags]"
        return 1
    fi

    local -a a=("$@") i=0
    while (( i < ${#a[@]} )) && [[ ${a[i]} == -S || ${a[i]} == --strict \
        || ${a[i]} == -D || ${a[i]} == --debug ]]; do
        ((i++))
    done
    local base="${a[i]%.*}"

    trap 'rm -f "$base"' RETURN INT TERM
    compile "$@" || return 1
    [[ "$base" != */* ]] && base="./$base"
    "$base"
    echo
}
