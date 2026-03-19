function fish_remove_paths --description 'Remove paths from fish_user_paths'
    for path in $argv
        set -e fish_user_paths[(contains -i $path $fish_user_paths)]
    end
end
