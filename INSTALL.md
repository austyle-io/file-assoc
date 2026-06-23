# Installation

## 1. Install dependencies

```bash path=null start=null
brew bundle install --file=Brewfile
```

Or install the runtime requirements manually:

```bash path=null start=null
brew install bash bc duti
```

`just`, `shellcheck`, and `shfmt` are only needed for development tasks. Install the BATS test stack with `just install-bats`, which installs the `bats-core` runner from Homebrew and initializes the vendored helper libraries.

The BATS helper libraries (`bats-support`, `bats-assert`, `bats-file`) are vendored as version-pinned git submodules under `test/helpers/lib/` (no third-party Homebrew tap). If you cloned without `--recurse-submodules`, initialize them with:

```bash path=null start=null
git submodule update --init test/helpers/lib
```

## 2. Add the commands to PATH

From the repository root, symlink the wrappers into a directory on your `PATH` (`~/.local/bin` is a common choice):

```bash path=null start=null
mkdir -p ~/.local/bin
ln -sf "$PWD/bin/file-assoc-setup" ~/.local/bin/file-assoc-setup
ln -sf "$PWD/bin/file-assoc-reset" ~/.local/bin/file-assoc-reset
```

If `~/.local/bin` is not already on your `PATH`, add it to your shell startup file:

```bash path=null start=null
export PATH="$HOME/.local/bin:$PATH"
```

Reload your shell, then verify:

```bash path=null start=null
which file-assoc-setup
which file-assoc-reset
file-assoc-setup --help
file-assoc-reset --help
```

## 3. Apply and reset

Apply system-wide file associations:

```bash path=null start=null
file-assoc-setup
```

Preview reset behavior before changing xattrs:

```bash path=null start=null
file-assoc-reset --dry-run --verbose ~/Downloads
```

Clear per-file overrides after review:

```bash path=null start=null
file-assoc-reset ~/Downloads
```

## Alternative: use just

From the repo root:

```bash path=null start=null
just setup-file-associations
just reset-file-associations-preview ~/Downloads
just reset-file-associations ~/Downloads
```
