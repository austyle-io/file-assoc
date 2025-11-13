# How to Apply Phase 5 Changes

## The Problem

The Claude Code environment cannot push to GitHub due to authentication restrictions (403 errors). The branch `claude/phase-5-gnu-parallel` exists only in the container, not on GitHub.

## The Solution: Apply the Patch File

I've created a git patch file containing all Phase 5 changes: **`phase-5-complete.patch`**

## Quick Apply Instructions

### On Your Local Machine:

```bash
cd /path/to/file-assoc

# Ensure you're on main and up to date
git checkout main
git pull origin main

# Download the patch file from this repository
# (The file is at the root: phase-5-complete.patch)

# Apply the patch
git am < phase-5-complete.patch

# This creates 3 commits:
# 1. feat(phase-5): add GNU Parallel integration module
# 2. docs: add Phase 5 pull request description
# 3. docs: add push instructions for Phase 5 branch

# Push to GitHub
git push origin main
```

## Alternative: Manual Application

If `git am` doesn't work, you can apply manually:

```bash
# Create a feature branch
git checkout -b feature/phase-5-gnu-parallel

# Apply the patch
patch -p1 < phase-5-complete.patch

# Review changes
git status
git diff

# Stage and commit
git add lib/parallel.sh tests/test-parallel.sh justfile docs/ARCHITECTURE.md
git commit -m "feat(phase-5): add GNU Parallel integration module"

git add .github/PHASE_5_PR.md
git commit -m "docs: add Phase 5 pull request description"

git add PUSH_INSTRUCTIONS.md
git commit -m "docs: add push instructions for Phase 5 branch"

# Push
git push -u origin feature/phase-5-gnu-parallel
```

## What's in the Patch

### Commit 1: Main Implementation
- `lib/parallel.sh` (+290 lines) - GNU Parallel wrapper module
- `tests/test-parallel.sh` (+345 lines) - Test suite (10 tests)
- `justfile` (+9 lines) - Added parallel tests
- `docs/ARCHITECTURE.md` (+89 lines) - Updated documentation

### Commit 2: PR Description
- `.github/PHASE_5_PR.md` (+186 lines) - Complete PR description

### Commit 3: Push Instructions
- `PUSH_INSTRUCTIONS.md` (+180 lines) - Detailed instructions

## Verify the Patch

```bash
# Check what the patch will do (without applying)
git apply --stat phase-5-complete.patch

# Check if it will apply cleanly
git apply --check phase-5-complete.patch
```

## After Applying

### Run Tests

```bash
# Run all unit tests
bash tests/test-parallel.sh

# Or use justfile
just test-unit
```

### Create PR (Optional)

If you applied to a feature branch:

```bash
gh pr create \
  --title "feat(phase-5): Add GNU Parallel integration module" \
  --body-file .github/PHASE_5_PR.md \
  --base main
```

## Why This Happens

The Claude Code environment uses a local proxy (`http://127.0.0.1`) for git operations, which has authentication restrictions. This is a security feature but prevents direct pushes.

## Files Included

All Phase 5 work is in this patch:
- ✅ Complete GNU Parallel integration module
- ✅ 10 comprehensive tests (all passing)
- ✅ Full documentation updates
- ✅ Ready-to-use PR description
- ✅ Integrated into justfile

Total: +1,099 lines of production code, tests, and documentation

## Need Help?

If the patch doesn't apply cleanly:
1. Check you're on the latest main: `git pull origin main`
2. Try the manual application method above
3. Or manually create the files using the content in this repository

## Files to Download from Repository

If patch doesn't work, you can manually copy these files from this repository:
1. `lib/parallel.sh`
2. `tests/test-parallel.sh`
3. `.github/PHASE_5_PR.md`
4. `PUSH_INSTRUCTIONS.md`

And apply these changes:
- `justfile` (see diff in patch)
- `docs/ARCHITECTURE.md` (see diff in patch)
