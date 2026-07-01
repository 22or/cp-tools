# cp-tools

Competitive programming tools: shell helpers, an optional reference template, and stress testing.

## Install

From this checkout (any path):

```bash
./install.sh
```

Installs `cp-tools.sh` to `~/.local/share/cp-tools/` and adds a source line to `~/.bashrc`. Prompts for your C++ template path and saves it in `~/.local/share/cp-tools/env.sh`. Re-run after pulling to refresh the installed helpers (you can keep or update `CPP_TEMPLATE`).

```bash
./uninstall.sh
```

## Shell commands

`cpcp`, `compile`, and `run` — installed to `~/.local/share/cp-tools/cp-tools.sh`.

Set your template path during `./install.sh`, or edit `~/.local/share/cp-tools/env.sh` later:

```bash
export CPP_TEMPLATE="$HOME/template.cpp"
```

```bash
cpcp problem.cpp

compile file.cpp [extra g++ flags]
run file.cpp [extra g++ flags]
run -S file.cpp          # extra warnings
run -D file.cpp          # libstdc++ debug mode
CPP_STRICT=1 run file.cpp
CPP_DEBUG=1 run file.cpp
```

## stress-test.sh

```bash
./stress-test.sh <solution.cpp> <brute.cpp> <generator.cpp> <N>
```

## template.cpp

Optional starter file included in this repo if you want a starting point — not installed by `install.sh`. Copy or point `CPP_TEMPLATE` at your own file.

* uses compile flag `LOCAL` to enable/disable things based on whether you are running locally
* debug requires C++17
