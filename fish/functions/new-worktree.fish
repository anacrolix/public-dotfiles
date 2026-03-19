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
    argparse 'remote=' -- $argv
    or return
    set -q _flag_remote; or set -l _flag_remote origin

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
    set -l base $_flag_remote/main
    if test (count $argv) -eq 2
        set base $argv[2]
    end
    set -l dir $repo/.worktrees/$name
    git -C $repo fetch $_flag_remote
    set -l prefixed $gh_user/$name
    if git -C $repo show-ref --verify --quiet refs/heads/$name
        git -C $repo worktree add $dir $name
    else if git -C $repo show-ref --verify --quiet refs/remotes/$_flag_remote/$name
        git -C $repo worktree add -b $name --track $dir $_flag_remote/$name
    else if git -C $repo show-ref --verify --quiet refs/heads/$prefixed
        git -C $repo worktree add $dir $prefixed
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
