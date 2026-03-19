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

## bin/anacrolix.mk

Make include file defining standard Go build/test targets.

## bin/aws-endpoint-env

Wraps a command, conditionally injecting `AWS_ENDPOINT_URL` based on the environment.

## bin/debupall

Runs `apt-get dist-upgrade` with standard flags for unattended upgrades.

## bin/erusvc

Lightweight service supervisor: runs a process, restarts it on failure, and logs output.

## bin/find_mirrors.sh

Fetches the Ubuntu mirror list from Launchpad and filters for fast/valid mirrors.

## bin/find-go-pkg

Searches `$GOPATH` for a Go package directory by name.

## bin/ft

Runs a command inside a pseudo-TTY using `script(1)`, preserving terminal output for piping.

## bin/git-submodule-add-existing

Registers an already-cloned directory as a git submodule without re-cloning it.

## bin/go-fuzz-all

Runs `go test -fuzz` against all fuzz targets in matching packages.

## bin/go-local-replaces

Adds or removes `replace` directives in `go.mod` to point dependencies at local paths.

## bin/go-rewrite-imports

Batch-rewrites Go import paths across a directory tree using `sed`.

## bin/gocmdpkg

Lists directories under `$GOPATH/src` that contain a `package main`.

## bin/godocd

Starts a local `godoc` HTTP server.

## bin/gorace

Runs `go test -race` with any extra args passed through.

## bin/just-anacrolix

Justfile with Go test/build recipes for use as a base include.

## bin/listeners

Lists processes listening on TCP and UDP ports (wraps `ss`/`netstat`).

## bin/meld-osx

Opens files in the Meld diff/merge tool on macOS via the app bundle.

## bin/osxfuse-dirfix.sh

Removes stale empty directories left behind by failed FUSE unmounts in `/Volumes`.

## bin/pprint-argv

Prints each argument on its own line, useful for debugging argument passing.

## bin/rgr

Ripgrep-and-replace: finds lines matching a pattern and rewrites them in-place.

## bin/rsync-src

Rsync wrapper tuned for syncing source trees: excludes build artifacts and VCS dirs.

## bin/shebang-fix

Strips the erroneous space in `#! /usr/bin/env` shebangs, normalising them to `#!/usr/bin/env`.

## bin/ssh-tmux

SSHes to a host and creates or reattaches to a named tmux session.

## bin/vgo

Runs a Go command with `GO111MODULE=on` forced.

## bin/why-dep.py

Traces the Go import graph to explain why a given package is a transitive dependency.

## fish/functions

Fish shell functions. To use them, drop a file in `~/.config/fish/conf.d/` that prepends the functions directory to `fish_function_path`:

```fish
# ~/.config/fish/conf.d/public-dotfiles.fish
set -p fish_function_path ~/path/to/this-repo/fish/functions
```
