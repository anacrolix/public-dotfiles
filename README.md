# public-dotfiles

Public scripts from `~/bin`.

## bin/tag-downstreams

Tags commits in the current Go module's repo to track which upstream version each downstream release depends on. For each downstream tag/branch, creates a lightweight tag `downstreams/<name>/<tag>` pointing to the upstream commit. Only tags when the upstream version changes between consecutive downstream releases. Stale tags are pruned by default.

Options: `--no-fetch`, `--no-prune-stale`, `--branch-pattern`, `--tag-pattern`

## bin/git-prune-ancestors

Removes branches that are ancestors of another remote branch. Dry-run by default; pass `--delete` to act.

## bin/git-prune-merged

Cleans up local branches whose PRs were squash-merged on GitHub. Uses `gh` to compare local branch tips against what GitHub recorded at merge time. Dry-run by default; pass `--delete` to act.

## bin/pr-table.py

Shows a summary table of open and recently closed/merged pull requests for the authenticated GitHub user. Accepts `--since` with durations (`2w ago`, `3 days`) or dates.

## bin/workflow-plumber

Lists and cancels GitHub Actions workflow runs. Subcommands: `list`, `cancel`, `stats`, `jobs`.

## bin/promote-claude-allowed

Interactively promotes allowed shell commands from `.claude/settings.local.json` up to `settings.json` or the global `~/.claude/settings.json`.
