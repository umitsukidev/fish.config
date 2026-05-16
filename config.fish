set uname_m (uname -m)

set -x ENV $uname_m $ARCH

set -x ARCH $uname_m
set -x EDITOR nvim

# Homebrew
if status is-interactive
    # Commands to run in interactive sessions can go here

    # PATH
    if test $uname_m = arm64
        set PATH /opt/homebrew/bin $PATH
    else if test $uname_m = x86_64
        set PATH /usr/local/bin $PATH
    end
end

# setup Cargo
set -gx RUSTUP_HOME $HOME/.rustup
set -gx CARGO_HOME $HOME/.cargo
fish_add_path $CARGO_HOME/bin
fish_add_path $RUSTUP_HOME

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

# setup prompt
# @fish-lsp-disable-next-line 1004
source {$HOME}/.config/fish/user/prompt.fish

# pnpm
set -gx PNPM_HOME {$HOME}/Library/pnpm
if not string match -q -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

# activate mise
if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims | source
end

# iTerm2 integration
# @fish-lsp-disable-next-line 1004
test -e {$HOME}/.iterm2_shell_integration.fish; and source {$HOME}/.iterm2_shell_integration.fish

# Mole shell completion
set -l output (mole completion fish 2>/dev/null); and echo "$output" | source

# Set up fzf key bindings
fzf --fish | source
set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border"
set -gx FZF_CTRL_T_OPTS "--preview 'test -d {} && eza -T -L 2 --color=always --icons {} || bat --color=always --line-range :300 {}'"
# Setup zoxide
zoxide init fish --cmd cd | source

# Setup eza
if type -q eza
    alias ls 'eza --icons --git'
    alias ll 'eza -al --icons --git'
    alias lt 'eza -T --icons --git' # ツリー表示
end

# bat alias
abbr -a less bat

# use chrome from cli
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"

# use processing from cli
alias processing="/Applications/Processing.app/Contents/MacOS/Processing"

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

# @fish-lsp-disable-next-line 1004
source {$HOME}/.config/op/plugins.sh

abbr -a c --command docker compose
