function starship_transient_prompt_func
    starship module line_break
    starship module time
    set username_output (string replace " in" "" (starship module username))
    if test -n "$username_output"
        echo -n "as "
    end
    echo -n "$username_output"
    echo -n "on "
    starship module shell
    starship module character
end

function starship_transient_rprompt_func
    if test "$status" -ne 0
        echo -n "was "
        starship module --status "$status" status
    end
    echo -n "in "
    starship module directory
end

starship init fish | source

enable_transience
