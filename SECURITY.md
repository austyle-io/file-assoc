# Security

This repo contains macOS shell scripts that modify Launch Services metadata.

## Safety model

- `file-assoc-setup` calls `duti` with `config/macos-file-associations.duti`.
- `file-assoc-reset` scans a target directory and removes only the `com.apple.LaunchServices.OpenWith` extended attribute.
- File contents are not edited by the reset script.

Use `--dry-run --verbose` before running a live reset on user directories.

## Local checks

Run:

```bash path=null start=null
just quality
just test-integration
```

Before publishing changes, scan for secrets with your normal git-secrets workflow.

## Reporting issues

Do not open a public issue for a sensitive vulnerability. Use GitHub private vulnerability reporting or contact the maintainer directly.
