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
compile [-S] [-D] [-F] [-o bin] file.cpp [g++ flags...]
run [-S] [-D] [-F] file.cpp [g++ flags...]
```

`compile file.cpp` writes the binary to `file` (override with `-o`), and fails rather than write to a path that exists but is not a regular file.

Both accept the stem too — `run file` means `file.cpp`. That is what tab completion gives once the binary sits next to the source, and it used to die with g++'s "input file is the same as output file".

`run` deletes its binary afterwards, so it never touches `file`: it builds to a scratch `.file.run.XXXXXX` beside the source (falling back to `$TMPDIR` when that directory is not writable) and removes it on exit. A binary kept by an earlier `compile` therefore survives a `run`. `run` owns that `-o` and rejects one of your own — use `compile -o` to keep a binary somewhere specific.

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
