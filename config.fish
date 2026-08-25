set -x EDITOR nvim

# Homebrew
if status is-interactive
    /opt/homebrew/bin/brew shellenv | source

    # gnu packages
    set -l gnu_packages gawk gnu-sed coreutils findutils grep
    for pkg in $gnu_packages
        fish_add_path -g /opt/homebrew/opt/$pkg/libexec/gnubin
        set -gx MANPATH "/opt/homebrew/opt/$pkg/libexec/gnuman" $MANPATH ""
    end
    fish_add_path -g /opt/homebrew/opt/diffutils/bin
    set -gx MANPATH /opt/homebrew/opt/diffutils/share/man $MANPATH ""

    # container
    fish_add_path -g /opt/homebrew/opt/container/bin
end

# setup Cargo
set -gx RUSTUP_HOME $HOME/.rustup
set -gx CARGO_HOME $HOME/.cargo
fish_add_path -g $CARGO_HOME/bin
fish_add_path -g $RUSTUP_HOME

# yazi alias
function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if read -z cwd <"$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# nvim alias
abbr -a vi nvim
abbr -a nv nvim

# lazygit alias
abbr -a lg lazygit

abbr -a mc mcat

# iTerm2 integration
# @fish-lsp-disable-next-line 1004
test -e {$HOME}/.iterm2_shell_integration.fish; and source {$HOME}/.iterm2_shell_integration.fish

if status is-interactive
    # Set up fzf key bindings
    fzf --fish | source
    set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border"
    set -gx FZF_CTRL_T_OPTS "--preview 'test -d {} && eza -T -L 2 --color=always --icons always {} || bat --color=always --line-range :300 {}'"

    # Setup zoxide
    zoxide init fish --cmd cd | source

    # Setup eza
    if type -q eza
        alias ls 'eza --icons --git'
        alias ll 'eza -al --icons --git'
        alias lt 'eza -T --icons --git' # ツリー表示
    end
end

# setup atuin
atuin init fish --disable-up-arrow | source

# use chrome from cli
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"

# use processing from cli
alias processing="/Applications/Processing.app/Contents/MacOS/Processing"

# launch screensaver from cli
alias screensaver="open -a ScreenSaverEngine"
abbr -a ss screensaver

# use yoink from cli
alias yoink="open -a Yoink"

# venvのabbr
abbr -a activate . .venv/bin/activate.fish

# デスクトップを綺麗にする/戻す
function clean-desktop
    switch $argv[1]
        case on
            # デスクトップアイコンを非表示
            defaults write com.apple.finder CreateDesktop -bool false
            # ウィジェットを非表示
            defaults write com.apple.WindowManager StandardHideWidgets -bool true
            # 設定を反映
            killall Finder
            echo "Desktop cleaning: ON"

        case off
            # デスクトップアイコンを表示
            defaults write com.apple.finder CreateDesktop -bool true
            # ウィジェットを表示
            defaults write com.apple.WindowManager StandardHideWidgets -bool false
            # 設定を反映
            killall Finder
            echo "Desktop cleaning: OFF"

        case '*'
            echo "Usage: clean-desktop [on|off]"
    end
end

function docker-exec
    # 1. 起動中のコンテナ名をfzfで選択
    set -l container (docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | fzf --height 40% --reverse --header-lines=1 | awk '{print $1}')
    if test -z "$container"
        return
    end

    # 2. 後ろにコマンドがある場合は bash 固定で実行して終了
    if test (count $argv) -gt 0
        set -l cmd_str (string join " " $argv)
        docker exec -it $container sh -c "$cmd_str"
        return
    end

    # 3. コマンドなし起動の場合：コンテナ内に存在するシェルを調査
    set -l available_shells
    if docker exec $container which fish >/dev/null 2>&1
        set -a available_shells fish
    end
    if docker exec $container which zsh >/dev/null 2>&1
        set -a available_shells zsh
    end
    if docker exec $container which bash >/dev/null 2>&1
        set -a available_shells bash
    end
    if docker exec $container which sh >/dev/null 2>&1
        set -a available_shells sh
    end

    if test (count $available_shells) -eq 0
        echo "No available shells found in $container"
        return
    end

    # 4. 存在するシェルをfzfで選択
    set -l chosen_shell (printf "%s\n" $available_shells | fzf --height 30% --reverse --header "Select shell for $container")
    if test -z "$chosen_shell"
        return
    end

    # 5. 選択したシェルで直接インタラクティブに入る
    docker exec -it $container $chosen_shell
end
abbr -a de docker-exec
abbr -a dcu docker compose up -d

source "$HOME/.config/op/plugins.sh"

abbr -a c --command docker compose

# pnpm
set -gx PNPM_HOME "$HOME/Library/pnpm"
if not string match -q -- "$PNPM_HOME/bin" $PATH
    set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end

# Added by Antigravity CLI installer
fish_add_path -g "$HOME/.local/bin"

# Added by Antigravity IDE
fish_add_path -g "$HOME/.antigravity-ide/antigravity-ide/bin"

abbr -a agyide antigravity-ide

# cloudflare tunnel
function tunnel
    caddy reverse-proxy --from :18787 --to :$argv
end

# select a zellij session with fzf and attach to it
function zellija
    set -l sessions (zellij list-sessions --short)
    set -l current_session $ZELLIJ_SESSION_NAME

    if test -n "$current_session"
        set sessions (for session in $sessions
            if test "$session" != "$current_session"
                printf '%s\n' "$session"
            end
        end)
    end

    set -l selected_session (printf '%s\n' $sessions | fzf --height 40% --layout=reverse --border --prompt='zellij attach> ')
    if test -n "$selected_session"
        zellij attach "$selected_session"
    end
end
abbr -a zela zellija

# interactively run a pnpm script from package.json
function pnr
    if not test -f package.json
        echo "package.json not found in $PWD"
        return 1
    end

    if not type -q jq
        echo "pnr requires jq"
        return 1
    end

    set -l scripts (jq -r '.scripts // {} | to_entries[] | [.key, .value] | @tsv' package.json 2>/dev/null | awk -F '\t' '{ printf "%-24s\t%s\n", $1, $2 }')
    if test $status -ne 0
        echo "Failed to read scripts from package.json"
        return 1
    end
    if test (count $scripts) -eq 0
        echo "No npm scripts found in package.json"
        return 1
    end

    set -l script (printf '%s\n' $scripts | fzf --height 40% --layout=reverse --border --delimiter='\t' --with-nth=1 --accept-nth=1 --prompt='pnpm run> ' --preview='printf "%s\\n" {2..} | bat --language=sh --style=plain --color=always --theme=auto:system --paging=never' --preview-window=right:60%,wrap)
    if test -n "$script"
        pnpm run "$script"
    end
end

# activate mise
if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims | source
end

fish_add_path -g "$HOME/.bun/bin"

# setup prompt
source "$HOME/.config/fish/user/prompt.fish"
