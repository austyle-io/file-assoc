# file-assoc

Standalone macOS file-association tools.

macOS resolves file associations in two layers:

1. System-wide defaults in Launch Services, applied here with `duti`.
2. Per-file overrides stored as `com.apple.LaunchServices.OpenWith` extended attributes, cleared here with `xattr`.

This repo contains only the pieces needed for that workflow:

- `bin/file-assoc-setup` applies `config/macos-file-associations.duti`.
- `bin/file-assoc-reset` clears per-file Launch Services overrides under a target directory.
- `scripts/reset-file-associations.sh` is the reset implementation.
- `docs/LAUNCH_SERVICES_ANALYSIS.md` explains the macOS behavior and performance tradeoffs.

## Requirements

- macOS
- Bash 4+
- `duti`
- `bc`
- `just`, `shellcheck`, and `shfmt` for development tasks
- `bats-core` (+ `bats-support`, `bats-assert`, `bats-file`) to run the tests

Install the Homebrew dependencies:

```bash path=null start=null
brew bundle install --file=Brewfile
```

## Install

From the repository root, symlink the command wrappers into a directory on your `PATH` (`~/.local/bin` is a common choice):

```bash path=null start=null
mkdir -p ~/.local/bin
ln -sf "$PWD/bin/file-assoc-setup" ~/.local/bin/file-assoc-setup
ln -sf "$PWD/bin/file-assoc-reset" ~/.local/bin/file-assoc-reset
```

If `~/.local/bin` is not already on your `PATH`, add it to your shell startup file:

```bash path=null start=null
export PATH="$HOME/.local/bin:$PATH"
```

The wrappers resolve their real location through the symlink, so they work from anywhere and do not depend on `~/dotfiles`. Alternatively, add this repo's `bin/` directory to your `PATH`, or invoke the scripts directly.

## Usage

Apply system-wide defaults:

```bash path=null start=null
file-assoc-setup
```

Edit the duti config:

```bash path=null start=null
file-assoc-setup --configure
```

Preview per-file override cleanup:

```bash path=null start=null
file-assoc-reset --dry-run --verbose ~/Downloads
```

Clear per-file overrides:

```bash path=null start=null
file-assoc-reset ~/Downloads
```

Limit cleanup to specific extensions:

```bash path=null start=null
file-assoc-reset --ext md --ext sh ~/Documents
```

## Reset safety

`file-assoc-reset` mutates files only by deleting the `com.apple.LaunchServices.OpenWith` extended attribute. It does not change file contents.

Recommended workflow:

1. Run `file-assoc-setup` to apply system defaults.
2. Run `file-assoc-reset --dry-run --verbose <dir>` to preview.
3. Run `file-assoc-reset <dir>` only after reviewing the preview.

For unattended or scripted runs, use `--no-confirm` only with a narrow target directory or explicit `--ext` filters.

## Reset options

Common options:

- `--dry-run`, `-d`: preview without changing xattrs.
- `--verbose`, `-v`: show detailed output.
- `--path`, `-p`: target directory, taking precedence over a positional directory.
- `--ext`, `-e`: extension to process; repeatable.
- `--max-files`: prompt before scanning more than this number of files.
- `--workers`: parallel worker count; `0` auto-detects CPU cores.
- `--no-parallel`: process sequentially.
- `--sample-size`: sample size before a full scan.
- `--skip-sampling`: skip the sampling phase.
- `--log-file`: write logs to a specific file.

Default logs are written under `~/.file-assoc/logs`.

## Just recipes

```bash path=null start=null
just --list
just check-deps
just setup-file-associations
just reset-file-associations-preview ~/Downloads
just test-all
```

## Development

Run static checks:

```bash path=null start=null
just quality
```

Run tests (BATS):

```bash path=null start=null
just install-bats      # one-time: bats-core runner + init vendored helper submodules
just test-integration  # runs test/integration/*.bats
```

The BATS suite lives in `test/`, with shared setup in `test/helpers/test_helper.bash`. The helper libraries (`bats-support`, `bats-assert`, `bats-file`) are vendored as version-pinned git submodules under `test/helpers/lib/` — no third-party Homebrew tap. Tests use isolated temporary sandboxes (`_common_setup`/`_common_teardown`) and never modify real user files.

## Configuration

`config/macos-file-associations.duti` maps common development files to Visual Studio Code (bundle ID `com.microsoft.VSCode`). Edit it with `file-assoc-setup --configure`, then re-apply with `file-assoc-setup`.

Check the current handler for an extension:

```bash path=null start=null
duti -x md
```

Check whether a file has a per-file override:

```bash path=null start=null
xattr -l path/to/file.md | grep LaunchServices
```

## Note on `error -50` / skipped extensions

`file-assoc-setup` prints a summary like `Applied: N` / `Skipped: M`. Skipped extensions are those that resolve only to a macOS *dynamic UTI* (`dyn.…`); `duti` cannot set a default handler for them and macOS returns `error -50`. This is a macOS/Launch Services limitation, not a config error — the rest of the mappings still apply.

To bind a skipped type to an app anyway, use Finder: right-click a file of that type -> **Open With -> Other -> (app) -> Always Open With** (or Get Info -> "Open with" -> "Change All…"), which works where the `duti` API does not.
