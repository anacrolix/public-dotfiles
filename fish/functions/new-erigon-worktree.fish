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
function new-erigon-worktree
    argparse -- $argv
    or return

    if test (count $argv) -lt 1 -o (count $argv) -gt 2
        echo "Usage: new-erigon-worktree <name> [base-branch]"
        return 1
    end
    set -l name (string replace 'anacrolix/' '' $argv[1])
    set -l branch anacrolix/$name
    set -l base origin/main
    if test (count $argv) -eq 2
        set base $argv[2]
    end
    set -l dir ~/erigon/src/erigon-worktrees/$name
    git -C ~/erigon/src/erigon-git fetch
    git -C ~/erigon/src/erigon-git worktree add -b $branch $dir $base
        or git -C ~/erigon/src/erigon-git worktree add $dir $branch
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
