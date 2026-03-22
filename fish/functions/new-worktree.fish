# Submodule object/LFS sharing via ref-shim (one-time setup on main repo):
#
#   git init --bare ~/erigon/src/erigon-git/.git/ref-shim
#   ln -sf ../modules ~/erigon/src/erigon-git/.git/ref-shim/modules
#   echo "$(cd ~/erigon/src/erigon-git/.git/ref-shim && pwd)/objects" \
#       >> ~/erigon/src/erigon-git/.git/objects/info/alternates
#   git -C ~/erigon/src/erigon-git config submodule.alternateLocation superproject
#   git -C ~/erigon/src/erigon-git config submodule.alternateErrorStrategy info
#
# How it works: git submodule update --init reads the superproject's alternates,
# strips /objects, appends /modules/<name>/objects, and writes that path into each
# new submodule's own alternates file. The ref-shim is a bare repo whose modules/
# symlinks back to .git/modules/, so the resolved path is the real main-repo module.
# This avoids cloning submodule objects per-worktree (~5.6 GB saved each time).
#
# If a submodule was renamed (e.g. interfaces -> node/interfaces), create a symlink
# in .git/modules/ so the name matches:
#   mkdir -p ~/erigon/src/erigon-git/.git/modules/node
#   ln -sf ../interfaces ~/erigon/src/erigon-git/.git/modules/node/interfaces
#
# Worktrees are placed in .worktrees/ inside the repo. Add this to your global gitignore
# (or the repo's .git/info/exclude) so git doesn't track it:
#   echo '.worktrees/' >> ~/.gitignore
#
function new-worktree
    argparse 'h/help' 'remote=' -- $argv
    or return
    set -q _flag_remote; or set -l _flag_remote origin

    if set -q _flag_help
        echo "Usage: new-worktree [--remote=<remote>] <name> [base-branch]"
        echo ""
        echo "Create a new git worktree under .worktrees/<name>."
        echo ""
        echo "Options:"
        echo "  --remote=<remote>  Remote to fetch from and use as base (default: origin)"
        echo "  -h, --help         Show this help message"
        echo ""
        echo "Arguments:"
        echo "  <name>             Worktree/branch name (GitHub user prefix stripped if present)"
        echo "  [base-branch]      Base branch for new worktree (default: <remote>/main)"
        return 0
    end

    if test (count $argv) -lt 1 -o (count $argv) -gt 2
        echo "Usage: new-worktree [--remote=<remote>] <name> [base-branch]"
        return 1
    end

    set -l git_common (git rev-parse --git-common-dir 2>/dev/null)
    if test $status -ne 0
        echo "new-worktree: not inside a git repository"
        return 1
    end
    set -l repo (path resolve $git_common/..)

    set -l gh_user (gh api user --jq .login 2>/dev/null)
    if test -z "$gh_user"
        echo "new-worktree: could not determine GitHub username via gh api"
        return 1
    end

    set -l name (string replace "$gh_user/" '' $argv[1])
    set -l base_explicit false
    set -l base $_flag_remote/main
    if test (count $argv) -eq 2
        set base $argv[2]
        set base_explicit true
    end
    set -l dir $repo/.worktrees/$name
    if test -d $dir
        echo "new-worktree: $dir already exists on disk"
        return 1
    end
    git -C $repo worktree prune
    git -C $repo fetch $_flag_remote
    set -l prefixed $gh_user/$name
    set -l existing_ref ''
    if git -C $repo show-ref --verify --quiet refs/heads/$name
        set existing_ref refs/heads/$name
    else if git -C $repo show-ref --verify --quiet refs/remotes/$_flag_remote/$name
        set existing_ref refs/remotes/$_flag_remote/$name
    else if git -C $repo show-ref --verify --quiet refs/heads/$prefixed
        set existing_ref refs/heads/$prefixed
    end
    if test -n "$existing_ref"
        if test $base_explicit = true
            set -l existing_commit (git -C $repo rev-parse $existing_ref)
            set -l base_commit (git -C $repo rev-parse $base)
            if test "$existing_commit" != "$base_commit"
                echo "new-worktree: $existing_ref exists at $existing_commit, not at $base ($base_commit)"
                return 1
            end
        end
        if string match -q 'refs/remotes/*' $existing_ref
            git -C $repo worktree add -b $name --track $dir $existing_ref
        else
            git -C $repo worktree add $dir $existing_ref
        end
    else
        git -C $repo worktree add -b $prefixed $dir $base
    end
    cd $dir
    git submodule update --init
    set -l common (git rev-parse --git-common-dir)
    git submodule foreach --quiet '
        main_lfs="'"$common"'/modules/$name/lfs"
        if [ -d "$main_lfs" ]; then
            git config lfs.storage "$main_lfs"
        fi
    '
end
