---
name: rebase-personal
description: Bring `main` up to date with `upstream/main` and rebuild `personal` as `main` plus the personal feature branches. Use when the user asks to sync with upstream, rebase personal, or update main from upstream.
---

# Rebase personal on upstream

## Branch model

- `upstream` = LuciusChen/clutch. `origin` = jplindstrom/clutch (the fork).
- `main` = exact copy of `upstream/main`.
- `personal` = `main` + `git merge --no-ff <feature>` for each personal feature branch. Merge message: `Merge branch '<feature>' into personal`.
- Each feature branch is rebuilt directly on `main`.

## Rules

- Investigate and write the plan first. The user approves it before any change to state.
- Make backups before any rewrite: `main-YYMMDD`, `personal-YYMMDD`, `<feature>--pre-rebase-YYMMDD`.
- Never push. Give the user the push command, wrapped at 120 chars with trailing `\`:
  `git push --force-with-lease origin main personal <features...>`
- Never delete old branches. List them and let the user decide.
- No co-author line in commits (repo path contains `/personal/`). Keep the original commit messages.

## Step 1: Investigate (read-only)

- `git remote -v`, `git branch -vv`.
- Compare `git ls-remote upstream main` with `git rev-parse upstream/main`. A difference means the local ref is old.
- In plan mode, fetch in a scratch clone so the real repo stays unchanged:
  `git clone --no-checkout <repo> <scratchpad>/clutch-scratch`, add the `upstream` remote, fetch.
- Run `git merge-base main upstream/main`.
  - **Lesson (2026-10-31): upstream once rewrote all of its history, so there was no merge base.** Without a merge base, do not rebase. Reset `main` and cherry-pick the feature commits.
- Find features in `personal`: `git log main..personal`.
- For each feature branch: `git merge-base --is-ancestor <b> personal` and `git cherry personal <b>`.
- Look for feature branches that are not in `personal`. Ask the user whether to include them.

## Step 2: Does upstream already have the feature?

- `git grep -n -F <symbol> upstream/main` and `git log upstream/main --grep=<subject>`.
- Results on 2026-10-31. Re-check each time:
  - Superseded, dropped:
    - `copy-aligned-org-table` (upstream ca31953 "Align copied Org tables natively")
    - `export-csv` (upstream has full TSV/CSV export)
    - `clutch--result-source-table` (upstream fixed it with `clutch--row-identity-augmentable-sql-p`)
  - Kept: `clutch-connect-using-file` (4 commits), `copy-all-rows-and-cols` (ported by hand).

## Step 3: How do kept features interact with upstream?

Check that every symbol the feature uses still exists upstream.

- `clutch-connect-using-file` lives in `clutch-query.el`.
  - Upstream moved `clutch-connect` to `clutch-connection.el`, but `clutch-mode` and `clutch--console-ad-hoc-params` stay in `clutch-query.el`, so the feature stays there.
  - Depends on `clutch--connect-params-for-current-buffer` (reads `clutch--console-ad-hoc-params` first), `clutch--saved-connection-params`, `clutch--connection-alive-p`, `clutch-disconnect`.
  - Its tests use `clutch-test--with-connect-build-stubs`. Any extra `cl-letf` stub list must match the functions upstream `clutch-connect` calls (the old `clutch--clear-reconnect-metadata-caches` no longer exists).
- `copy-all-rows-and-cols` changes `clutch-result--copy-fmt` and `clutch-result-copy-dispatch` in `clutch-result.el`.
  - Upstream added `--no-header`, `clutch--transient-yes-no-switch` and `clutch-result--copy-scope-description`. Port by hand if the cherry-pick conflicts.
  - Current port: `-a` switch, `clutch-result--all-cells-rect`, works with `-r` and `-h`, heading says "Copy all rows and columns".
- Both features add a `# Personal Changelog` block at the top of `CHANGELOG.md`. The `personal` merge conflicts there. Resolve as one block, newest date first.

## Step 4: Rebuild

```
git branch main-YYMMDD main
git branch personal-YYMMDD personal
git branch <feature>--pre-rebase-YYMMDD <feature>
git fetch upstream
git checkout main && git reset --hard upstream/main
git checkout -B <feature> main && git cherry-pick <commits...>
git checkout -B personal main
git merge --no-ff <feature> -m "Merge branch '<feature>' into personal"
```

Put adaptations into the commit they belong to.

## Step 5: Verify

- Set `CLUTCH_EXTRA_LOAD_PATH` as in `CLAUDE.local.md`.
- Run `./test/run-ci.sh main` on clean `main` first to get the baseline failures.
  - On 2026-10-31 these 2 failed on pristine upstream (local dependency versions): `clutch-test-completion-quotes-backend-dialects`, `clutch-test-pg-array-mutation-builders-use-array-literals`.
- Run `./test/run-ci.sh main` on each feature branch.
- Run `./test/run-ci.sh main db byte-compile checkdoc` on `personal`. Expect only the baseline failures.
- Tips:
  - macOS needs `sed -i ''`.
  - With `clutch-test--type-keys`, copy menu keys are `t` TSV, `c` CSV, `o` Org.

## Step 6: Report

- Branch state, features dropped or kept and why, backups, test result with baseline failures, push command.
- Manual checks in Emacs:
  - Open `alpha.sql` (profile `alpha`), `M-x clutch-connect-using-file`: connects, buffer not renamed. Run again: disconnects.
  - `-- clutch: beta` in a buffer: connects to `beta`.
  - Result buffer, copy menu, `-a` then `o`: all visible rows as Org table. `-a` with `-r`: refine starts from all cells.
- List old superseded branches (`main-2607*`, `personal-*`, `*--pre-rebase-*`) for the user to delete.
