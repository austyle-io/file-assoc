# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this is

A small, self-contained pure-Bash macOS toolkit for managing file associations across the two tiers macOS uses:

- **System-wide defaults** — stored in the Launch Services database, applied with `duti` from `config/macos-file-associations.duti`.
- **Per-file overrides** — stored as `com.apple.LaunchServices.OpenWith` extended attributes on individual files; removing them lets the system default take over.

`file-assoc-setup` applies the system-wide layer; `file-assoc-reset` clears the per-file layer. Most of the code (and complexity) lives in the reset path, which scans directories and clears xattrs in parallel. The repo is intentionally trimmed to this capability and nothing more.

## Layout

```
bin/file-assoc-setup               # wrapper: applies the duti config
bin/file-assoc-reset               # wrapper: runs the reset script
scripts/reset-file-associations.sh # the single reset implementation
config/macos-file-associations.duti # bundle_id  ext/UTI  role mappings
test/integration/*.bats            # BATS integration tests
test/helpers/test_helper.bash      # shared BATS setup/teardown + lib loading
docs/LAUNCH_SERVICES_ANALYSIS.md   # Launch Services / xattr deep dive
Brewfile  justfile  README.md  INSTALL.md  SECURITY.md
```

## Commands

The `justfile` is the canonical task runner. `just` (or `just --list`) shows all recipes.

- Lint: `just lint` (shellcheck over `bin/*` and `scripts/*.sh`)
- Format: `just format` / check only with `just format-check` (shfmt `-i 2 -bn -ci -sr`)
- All static checks: `just quality` (alias `just q`) — runs format-check + lint
- Tests: `just test-integration` (alias `just test`); `just test-all` runs quality + tests
- Apply associations: `just setup-file-associations`
- Reset overrides: `just reset-file-associations <dir>` / preview with `just reset-file-associations-preview <dir>`
- Deps: `just install-deps` (full Brewfile) / `just install-bats` (test stack only) / `just check-deps`

`.bats` files are **not** shellcheck/shfmt targets (bats is not plain bash syntax); lint/format only touch `bin/*` and `scripts/*.sh`.

## Architecture

Call flow: `bin/` wrappers → `just` recipe / `scripts/` entry point.

- `bin/file-assoc-setup` resolves the repo root relative to itself (`FILE_ASSOC_ROOT`, not `DOTFILES_DIR`) and execs `just setup-file-associations`. That recipe applies each mapping with `duti -s` individually and prints a summary (`Applied: N` / `Skipped: M`). It treats `duti`'s `error -50` (dynamic-UTI types macOS won't let you set) as an expected skip, and only fails on genuinely unexpected errors.
- `bin/file-assoc-reset` execs `scripts/reset-file-associations.sh` — a single ~1900-line script (there is no v2 / `lib/` split; that refactor was removed).

### Reset script (`scripts/reset-file-associations.sh`)

- Strict mode (`set -euo pipefail`). Counter increments use `x=$((x + 1))` (not `((x++))`) so they never trip `set -e` on a zero result.
- Flags: `--dry-run/-d`, `--verbose/-v`, `--path/-p`, `--ext/-e` (repeatable), `--max-files`, `--max-rate`, `--max-memory`, `--batch-size`, `--no-throttle`, `--no-confirm`, `--workers`, `--chunk-size`, `--no-parallel`, `--sample-size`, `--skip-sampling`, `--log-level`, `--log-file`.
- Logs default to `~/.file-assoc/logs` (override with `FILE_ASSOC_LOG_DIR`).
- A sampling phase estimates the hit rate before a full scan; sampling uses `shuf`, then `gshuf`, then an `awk` reservoir fallback.
- Parallel processing via `xargs -P`; sequential fallback with `--no-parallel`.
- **Non-interactive safety:** the interactive "press q to quit" monitor is skipped unless both stdin and stdout are TTYs, and an `EXIT` trap reaps background helpers and restores the terminal. This is what keeps the script from hanging when its output is captured (e.g. under BATS `run` or command substitution). Preserve this behavior.

## Testing

Tests are **BATS** (`bats-core` + `bats-support`/`bats-assert`/`bats-file`), under `test/`.

- `test/helpers/test_helper.bash` loads the helper libraries (Homebrew/Linux/CI prefixes), derives `PROJECT_ROOT` from `BASH_SOURCE`, and exposes `_common_setup`/`_common_teardown` (isolated `mktemp` sandbox; logs redirected into it) plus `make_fixture_dir` and `require_macos_xattr`.
- A `.bats` file loads it with `load '../helpers/test_helper'` and uses `setup`/`teardown` → `_common_setup`/`_common_teardown`.
- Every test asserts **both** `$status` (`assert_success`/`assert_failure`) and `$output`; isolate state in the sandbox; never mutate real user files.
- Run: `just test-integration` or `bats --recursive test/integration`. Install the stack with `just install-bats`. The live xattr test self-skips off macOS or without `xattr`.

## Gotchas

- **Bash 4.0+ required** (associative arrays, strict mode). macOS ships bash 3.2, so a Homebrew bash is needed — do not assume `/bin/bash`.
- **The reset path mutates real files** (it strips extended attributes). Always use `--dry-run` (and `--verbose`) when testing, e.g. `file-assoc-reset --dry-run --verbose ~/Downloads`.
- **macOS-specific.** `duti`, `xattr`, and Launch Services are macOS-only.
- **`error -50` on apply is expected**, not a bug: macOS refuses to set a default handler for extensions that resolve only to a dynamic UTI. `setup-file-associations` summarizes these as skipped; the Finder "Always Open With" route is the only reliable way to bind those types.
- **shellcheck is zero-tolerance** (`.shellcheckrc`): no global disables. Suppress only inline with `# shellcheck disable=SCxxxx: <reason>`. `external-sources=true` is set so sourced files are followed.

## Reference docs

- `docs/LAUNCH_SERVICES_ANALYSIS.md` — Launch Services, dynamic UTIs, and the sampling rationale.
- `README.md` / `INSTALL.md` — user-facing usage, PATH setup, and the `error -50` note.
- `SECURITY.md` — the reset safety model and local checks.
