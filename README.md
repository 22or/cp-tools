## Install

```bash
./install.sh
./uninstall.sh
```

Re-run `./install.sh` after pulling. It prompts for your C++ template path (`CPP_TEMPLATE` in `~/.local/share/cp-tools/env.sh`).

## Commands

`cpcp` copies your `CPP_TEMPLATE` to a new file (e.g. `cpcp a.cpp` for problem A). Fails if the file already exists.

```bash
cpcp problem.cpp
compile [-S] [-D] file.cpp [g++ flags...]
run [-S] [-D] file.cpp [g++ flags...]
```

`-S` — extra warnings. `-D` — libstdc++ debug mode. Or set `CPP_STRICT=1` / `CPP_DEBUG=1`.

## Stress test

```bash
./stress-test.sh <solution.cpp> <brute.cpp> <generator.cpp> <N>
```

## template.cpp

- `debug(...)` pretty-print for most data structures (enabled when `LOCAL` is defined — `compile`/`run` pass `-DLOCAL`)
- Custom hash for `unordered_map` / `unordered_set` on `uint64_t` and pairs
- `USE_LONGS` — `#define int long long` and `INF`; comment out for `int`
- `crand(l, r)` — uniform random in `[l, r]` via `mt19937_64`
- Fast I/O; commented `freopen` block for file I/O
