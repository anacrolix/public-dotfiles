#!/bin/bash
#
# osxfuse-dirfix.sh
#
# Iterate /Volumes/* and remove any directory that isn't in `mount`
# (ignores all symlinks, OSX creates one for root fs)
#
for f in /Volumes/*; do
    if [[ -d "$f" && ! -L "$f" ]]; then
        mount | grep "on $f" > /dev/null
        if [ $? -ne 0 ]; then
            rmdir "$f/.Spotlight-V100" &> /dev/null
            rmdir "$f/.Trashes" &> /dev/null
            rmdir "$f" &> /dev/null
        fi
    fi
done