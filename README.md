## Install

```bash
./install.sh
./uninstall.sh
```

Re-run `./install.sh` after pulling. It prompts for your C++ template path and whether `cpcp` should open new files in `$EDITOR` (saved in `~/.local/share/cp-tools/env.sh` as `CPP_TEMPLATE` and `CPCP_EDIT`).

## Commands

`cpcp` copies your `CPP_TEMPLATE` to a new file (e.g. `cpcp a.cpp` for problem A). Fails if the file already exists. Opens in `$EDITOR` when `CPCP_EDIT=1` (set at install) or with `-e` / `--edit`.

```bash
cpcp problem.cpp
cpcp -e problem.cpp
compile [-S] [-D] [-F] file.cpp [g++ flags...]
run [-S] [-D] [-F] file.cpp [g++ flags...]
```

`-S` — extra warnings. `-D` — libstdc++ debug mode. `-F` — drop ASan/UBSan and the libstdc++ assertions, which otherwise cost about 1.7x runtime; use it when a timing needs to resemble the judge's. Or set `CPP_STRICT=1` / `CPP_DEBUG=1` / `CPP_FAST=1`.

## Stress test

```bash
stress-test <solution.cpp> <brute.cpp> <generator.cpp> <N>
```

All three programs are built with the same sanitizers as `compile`. Set `CXXFLAGS` to override.

## template.cpp

- `debug(...)` pretty-print for most data structures (enabled when `LOCAL` is defined — `compile`/`run` pass `-DLOCAL`)
- Custom hash for `unordered_map` / `unordered_set` on `uint64_t` and pairs
- `USE_LONGS` — `#define int long long` and `INF`; comment out for `int`
- `crand(l, r)` — uniform random in `[l, r]` via `mt19937_64`
- Fast I/O; commented `freopen` block for file I/O
