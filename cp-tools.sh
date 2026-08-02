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

    if [[ -z "${1:-}" ]]; then
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

# Resolve the source argument, printing it on stdout.
#
# `compile foo` / `run foo` is what tab completion gives once `foo` (the binary)
# sits next to `foo.cpp`: completion stops at the prefix they share. Take it to
# mean the source. Without this, the binary becomes both input and output and
# g++ bails with "input file is the same as output file".
_cp_src() {
    local src="$1"
    case "$src" in
        *.cpp|*.cc|*.cxx|*.c++|*.C|*.c) ;;
        *) [[ -f "$src.cpp" ]] && src="$src.cpp" ;;
    esac
    if [[ ! -f "$src" ]]; then
        echo "${FUNCNAME[1]:-cp-tools}: no such source file: $1" >&2
        return 1
    fi
    case "$src" in
        *.cpp|*.cc|*.cxx|*.c++|*.C|*.c) ;;
        *) echo "${FUNCNAME[1]:-cp-tools}: not a C++ source file: $src" >&2; return 1 ;;
    esac
    printf '%s\n' "$src"
}

# Usage: [compile|run] [-S|--strict] [-D|--debug] [-F|--fast] [-o <bin>] <file.cpp> [extra g++ flags]
compile() {
    local strict=0 debug=0 fast=0 out=
    case "${CPP_STRICT:-}" in 1|yes|true|Y|y) strict=1 ;; esac
    case "${CPP_DEBUG:-}" in 1|yes|true|Y|y) debug=1 ;; esac
    case "${CPP_FAST:-}" in 1|yes|true|Y|y) fast=1 ;; esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -S|--strict) strict=1; shift ;;
            -D|--debug)  debug=1; shift ;;
            -F|--fast)   fast=1; shift ;;
            -o|--output)
                if [[ -z "${2:-}" ]]; then
                    echo "compile: $1 needs an output path" >&2
                    return 1
                fi
                out="$2"; shift 2 ;;
            *) break ;;
        esac
    done
    if [[ -z "${1:-}" ]]; then
        echo "Usage: compile [-S|--strict] [-D|--debug] [-F|--fast] [-o <bin>] <file.cpp> [extra g++ flags]"
        return 1
    fi

    local src
    src="$(_cp_src "$1")" || return 1
    shift
    [[ -n "$out" ]] || out="${src%.*}"
    if [[ -e "$out" && ! -f "$out" ]]; then
        echo "compile: output path is not a regular file: $out" >&2
        return 1
    fi

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
        "${check_flags[@]}" "${debug_flags[@]}" "${strict_flags[@]}" "$src" -o "$out" "$@" \
        || { echo "Compilation failed."; return 1; }
}

run() {
    local usage="Usage: run [-S|--strict] [-D|--debug] [-F|--fast] <file.cpp> [extra g++ flags]"
    if [[ -z "${1:-}" ]]; then
        echo "$usage"
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
    if [[ -z "${a[i]:-}" ]]; then
        echo "$usage"
        return 1
    fi
    local src
    src="$(_cp_src "${a[i]}")" || return 1
    a[i]="$src"

    # run owns -o (below), and a second one silently wins in g++: the binary
    # would land elsewhere and run would exec the empty placeholder.
    local j
    for (( j = i + 1; j < ${#a[@]}; j++ )); do
        case "${a[j]}" in
            -o|--output|-o?*)
                echo "run: -o is not supported — run deletes its binary; use compile -o" >&2
                return 1 ;;
        esac
    done

    # run deletes its binary when the program exits, so it must not write to the
    # name compile would pick: `foo` beside `foo.cpp` may be a directory or a
    # binary compile was meant to keep. Build to a scratch name next to the
    # source instead; mktemp both reserves the name and proves the directory is
    # writable.
    local dir="."
    [[ "$src" == */* ]] && dir="${src%/*}"
    local stem="${src##*/}"; stem="${stem%.*}"
    local bin
    bin=$(mktemp "$dir/.${stem}.run.XXXXXX" 2>/dev/null) \
        || bin=$(mktemp "${TMPDIR:-/tmp}/cp-run.XXXXXX") \
        || { echo "run: could not create a scratch binary path" >&2; return 1; }

    compile "${a[@]:0:i}" -o "$bin" "${a[@]:i}" || { rm -f "$bin"; return 1; }

    # Subshell so the cleanup trap dies with it. A trap set here would outlive the
    # function and fire on every later Ctrl-C in the interactive shell.
    ( trap 'rm -f "$bin"' EXIT INT TERM; "$bin" )
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
