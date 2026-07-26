#!/usr/bin/env bash
# Stress-test a CP solution against a brute on random inputs from a generator.
#
# Usage: stress-test.sh <solution.cpp> <brute.cpp> <gen.cpp> <N>
#
# Requires: g++
#
# All three programs are built with the same sanitizers as `compile`, so UB and
# out-of-bounds access surface here instead of silently skewing a comparison.
# Override CXX / CXXFLAGS to change that.
#
# Runtime: generator and both solutions must exit 0. Non-zero exit (e.g. assert,
# sanitizer abort, uncaught exception, return 1) or fatal signal (e.g. SIGSEGV →
# exit 139) stops the script and prints exit code, stderr, input, and any
# partial stdout.

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
# 10# so a leading zero is not read as octal (010 -> 8).
N_ITER=$((10#$N))
if (( N_ITER < 1 )); then
  echo "error: N must be at least 1, got: $N" >&2
  exit 1
fi

for f in "$SOL" "$BRUTE" "$GEN"; do
  if [[ ! -f "$f" ]]; then
    echo "error: file not found: $f" >&2
    exit 1
  fi
done

CXX=${CXX:-g++}
DEFAULT_CXXFLAGS="-std=c++17 -O2 -pipe -g -DLOCAL -D_GLIBCXX_ASSERTIONS"
DEFAULT_CXXFLAGS+=" -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all"
CXXFLAGS=${CXXFLAGS:-$DEFAULT_CXXFLAGS}

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/stress_test.XXXXXX") || {
  echo "error: could not create temp directory" >&2
  exit 1
}
trap 'rm -rf "$WORKDIR"' EXIT

# Human-readable hint for crashes (bash exit = 128 + signal).
exit_hint() {
  local ec=$1 sig name
  (( ec > 128 && ec <= 192 )) || return 0
  sig=$((ec - 128))
  if name=$(kill -l "$sig" 2>/dev/null) && [[ -n "$name" ]]; then
    printf ' [SIG%s]' "$name"
  else
    printf ' [signal %d]' "$sig"
  fi
}

# Print file contents; ensure the next script line is not glued to the last byte.
cat_with_nl() {
  local file=$1
  [[ ! -s "$file" ]] && return 0
  cat "$file"
  [[ $(tail -c 1 "$file") != $'\n' ]] && printf '\n'
}

BIN_SOL="$WORKDIR/sol"
BIN_BRUTE="$WORKDIR/brute"
BIN_GEN="$WORKDIR/gen"
INP="$WORKDIR/in.txt"
OUT_SOL="$WORKDIR/out_sol.txt"
OUT_BRUTE="$WORKDIR/out_brute.txt"

compile_one() {
  local src=$1 out=$2 name=$3
  if ! $CXX $CXXFLAGS "$src" -o "$out" 2>"$WORKDIR/${name}_build.err"; then
    echo "error: failed to compile $name ($src):" >&2
    cat "$WORKDIR/${name}_build.err" >&2
    exit 1
  fi
}

compile_one "$SOL" "$BIN_SOL" "solution"
compile_one "$BRUTE" "$BIN_BRUTE" "brute"
compile_one "$GEN" "$BIN_GEN" "generator"

# Set after printing \r progress so we only prepend \n to stderr when a line needs finishing.
PRINTED_PROGRESS=0

# Run one program; on non-zero exit, report and stop the script.
run_one() {
  local bin=$1 name=$2 stdin=$3 out=$4 iter=$5
  local err="$WORKDIR/$name.err" ec

  "$bin" <"$stdin" >"$out" 2>"$err"
  ec=$?
  (( ec == 0 )) && return 0

  (( PRINTED_PROGRESS )) && printf '\n' >&2
  echo "error: $name failed on iteration $iter (exit ${ec}$(exit_hint "$ec"))" >&2
  if [[ -s "$err" ]]; then
    echo "--- $name stderr ---" >&2
    cat "$err" >&2
  fi
  if [[ -s "$out" ]]; then
    echo "--- $name stdout (possibly partial) ---" >&2
    cat_with_nl "$out" >&2
  fi
  # For the generator, $out is the input — printing it again adds nothing.
  if [[ "$name" != generator ]]; then
    echo "--- input ---" >&2
    cat_with_nl "$INP" >&2
  fi
  exit 1
}

for ((i = 1; i <= N_ITER; i++)); do
  run_one "$BIN_GEN" generator /dev/null "$INP" "$i"
  run_one "$BIN_SOL" solution "$INP" "$OUT_SOL" "$i"
  run_one "$BIN_BRUTE" brute "$INP" "$OUT_BRUTE" "$i"

  if ! cmp -s "$OUT_SOL" "$OUT_BRUTE"; then
    # Progress uses \r on stderr; stdout shares the TTY cursor — newline first.
    printf '\n'
    echo "Mismatch on iteration $i / $N_ITER"
    echo "========== INPUT (from generator) =========="
    cat_with_nl "$INP"
    echo "========== SOLUTION OUTPUT ($SOL) =========="
    cat_with_nl "$OUT_SOL"
    echo "========== BRUTE OUTPUT ($BRUTE) =========="
    cat_with_nl "$OUT_BRUTE"
    echo "========== diff (solution vs brute) =========="
    diff -u "$OUT_SOL" "$OUT_BRUTE" || true
    exit 1
  fi

  printf '\rOK %d / %d' "$i" "$N_ITER" >&2
  PRINTED_PROGRESS=1
done

echo "" >&2
echo "All $N_ITER cases matched."
