#!/usr/bin/env bash
# Stress-test a CP solution against a brute on random inputs from a generator.
#
# Usage: cp_stress.sh <solution.cpp> <brute.cpp> <gen.cpp> <N>
#
# Requires: g++, awk (for decimal N; avoids bash octal like 010 -> 8)
#
# Runtime: generator and both solutions must exit 0. Non-zero exit (e.g. assert,
# uncaught exception, return 1) or fatal signal (e.g. SIGSEGV → exit 139) stops
# the script and prints exit code, stderr, input, and any partial stdout.

set -u

usage() {
  echo "Usage: $0 <solution.cpp> <brute.cpp> <gen.cpp> <N>" >&2
  echo "  Runs N times: gen -> stdin for both programs -> compare stdout." >&2
  exit 1
}

[[ $# -eq 4 ]] || usage

SOL=$1
BRUTE=$2
GEN=$3
N=$4

if ! [[ "$N" =~ ^[0-9]+$ ]]; then
  echo "error: N must be a decimal integer (digits only), got: $N" >&2
  exit 1
fi
# Bash arithmetic treats a leading 0 as octal (e.g. 010 -> 8). Force base-10 count.
N_DEC=$(awk -v s="$N" 'BEGIN { print s + 0 }')
if [[ "$N_DEC" -lt 1 ]]; then
  echo "error: N must be at least 1, got: $N" >&2
  exit 1
fi
N_ITER="$N_DEC"

for f in "$SOL" "$BRUTE" "$GEN"; do
  if [[ ! -f "$f" ]]; then
    echo "error: file not found: $f" >&2
    exit 1
  fi
done

CXX=${CXX:-g++}
CXXFLAGS=${CXXFLAGS:--std=c++17 -O2 -pipe -DLOCAL}

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/cp_stress.XXXXXX") || {
  echo "error: could not create temp directory" >&2
  exit 1
}
trap 'rm -rf "$WORKDIR"' EXIT

# Human-readable hint for crashes (bash exit = 128 + signal).
exit_hint() {
  local ec=$1
  if [[ "$ec" -le 128 ]] || [[ "$ec" -gt 192 ]]; then
    return 0
  fi
  local sig=$((ec - 128))
  case "$sig" in
    6) printf ' [SIGABRT]' ;;
    8) printf ' [SIGFPE]' ;;
    11) printf ' [SIGSEGV]' ;;
    4) printf ' [SIGILL]' ;;
    *) printf ' [signal %s]' "$sig" ;;
  esac
}

BIN_SOL="$WORKDIR/sol"
BIN_BRUTE="$WORKDIR/brute"
BIN_GEN="$WORKDIR/gen"
INP="$WORKDIR/in.txt"
OUT_SOL="$WORKDIR/out_sol.txt"
OUT_BRUTE="$WORKDIR/out_brute.txt"

compile() {
  local src=$1 out=$2 name=$3
  if ! $CXX $CXXFLAGS "$src" -o "$out" 2>"$WORKDIR/${name}_build.err"; then
    echo "error: failed to compile $name ($src):" >&2
    cat "$WORKDIR/${name}_build.err" >&2
    exit 1
  fi
}

compile "$SOL" "$BIN_SOL" "solution"
compile "$BRUTE" "$BIN_BRUTE" "brute"
compile "$GEN" "$BIN_GEN" "generator"

# Set after printing \r progress so we only prepend \n to stderr when a line needs finishing.
PRINTED_PROGRESS=0

for ((i = 1; i <= N_ITER; i++)); do
  "$BIN_GEN" >"$INP" 2>"$WORKDIR/gen.err"
  gen_ec=$?
  if [[ "$gen_ec" -ne 0 ]]; then
    [[ "$PRINTED_PROGRESS" -eq 1 ]] && printf '\n' >&2
    echo "error: generator failed on iteration $i (exit ${gen_ec}$(exit_hint "$gen_ec"))" >&2
    if [[ -s "$WORKDIR/gen.err" ]]; then
      echo "--- generator stderr ---" >&2
      cat "$WORKDIR/gen.err" >&2
    fi
    exit 1
  fi

  "$BIN_SOL" <"$INP" >"$OUT_SOL" 2>"$WORKDIR/sol.err"
  sol_ec=$?
  if [[ "$sol_ec" -ne 0 ]]; then
    [[ "$PRINTED_PROGRESS" -eq 1 ]] && printf '\n' >&2
    echo "error: solution failed on iteration $i (exit ${sol_ec}$(exit_hint "$sol_ec"))" >&2
    if [[ -s "$WORKDIR/sol.err" ]]; then
      echo "--- solution stderr ---" >&2
      cat "$WORKDIR/sol.err" >&2
    fi
    if [[ -s "$OUT_SOL" ]]; then
      echo "--- solution stdout (possibly partial) ---" >&2
      cat "$OUT_SOL" >&2
    fi
    echo "--- input ---" >&2
    cat "$INP" >&2
    exit 1
  fi

  "$BIN_BRUTE" <"$INP" >"$OUT_BRUTE" 2>"$WORKDIR/brute.err"
  brute_ec=$?
  if [[ "$brute_ec" -ne 0 ]]; then
    [[ "$PRINTED_PROGRESS" -eq 1 ]] && printf '\n' >&2
    echo "error: brute failed on iteration $i (exit ${brute_ec}$(exit_hint "$brute_ec"))" >&2
    if [[ -s "$WORKDIR/brute.err" ]]; then
      echo "--- brute stderr ---" >&2
      cat "$WORKDIR/brute.err" >&2
    fi
    if [[ -s "$OUT_BRUTE" ]]; then
      echo "--- brute stdout (possibly partial) ---" >&2
      cat "$OUT_BRUTE" >&2
    fi
    echo "--- input ---" >&2
    cat "$INP" >&2
    exit 1
  fi

  if ! cmp -s "$OUT_SOL" "$OUT_BRUTE"; then
    # Progress uses \r on stderr; stdout shares the TTY cursor — newline first.
    printf '\n'
    echo "Mismatch on iteration $i / $N_ITER"
    echo "========== INPUT (from generator) =========="
    cat "$INP"
    echo "========== SOLUTION OUTPUT ($SOL) =========="
    cat "$OUT_SOL"
    echo "========== BRUTE OUTPUT ($BRUTE) =========="
    cat "$OUT_BRUTE"
    echo "========== diff (solution vs brute) =========="
    diff -u "$OUT_SOL" "$OUT_BRUTE" || true
    exit 1
  fi

  printf '\rOK %d / %d' "$i" "$N_ITER" >&2
  PRINTED_PROGRESS=1
done

echo "" >&2
echo "All $N_ITER cases matched."
