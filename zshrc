# * Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# * Plugins (antidote)
source $(brew --prefix antidote)/share/antidote/antidote.zsh
antidote load

# * Completions
fpath+="$(brew --prefix)/share/zsh/site-functions"
autoload -Uz compinit && compinit -i
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Z-a}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true

# * History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS EXTENDED_HISTORY

# * Navigation
setopt AUTO_CD CORRECT NO_BEEP

# * Environment
export SHELL=/bin/zsh
export EDITOR='micro'
export PATH="$HOME/.local/bin:$PATH"
export HOMEBREW_NO_ENV_HINTS=1

# * Aliases
alias zshrc='micro ~/.zshrc'
alias reload='source ~/.zshrc'
alias mi='micro'

# * Starship prompt (must be last)
eval "$(starship init zsh)"

# * Auto-cd home when entering from macOS paths
case "$PWD" in
  /Users/*|/mnt/mac/*) cd ~ ;;
esac