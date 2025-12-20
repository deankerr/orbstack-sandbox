# ==============================================================================
# 1. THE FOUNDATION: HOMEBREW
# ==============================================================================
# Initializes Homebrew for Linux. This makes 'brew' available for the rest 
# of the script and your terminal sessions.
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# ==============================================================================
# 2. PLUGIN MANAGEMENT: ANTIDOTE
# ==============================================================================
# Antidote manages plugins fast. Make sure your plugins are listed in:
# ~/.zsh_plugins.txt (syntax: user/repo)
# Includes: zsh-users/zsh-autosuggestions, zsh-users/zsh-syntax-highlighting
source $(brew --prefix antidote)/share/antidote/antidote.zsh
antidote load

# ==============================================================================
# 3. ZSH SANE DEFAULTS & COMPLETIONS
# ==============================================================================
# Add Homebrew's completions to fpath (must be before compinit)
fpath+="$(brew --prefix)/share/zsh/site-functions"

# Initialize completion system
autoload -Uz compinit && compinit -i

# Better Menu Selection: Use arrow keys to navigate tab completion
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Z-a}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true

# History Settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY         # Share history between sessions
setopt HIST_IGNORE_DUPS      # Don't record duplicates
setopt HIST_IGNORE_SPACE     # Commands starting with space won't be saved
setopt HIST_REDUCE_BLANKS    # Tidy up the history file
setopt EXTENDED_HISTORY      # Save timestamps

# Better Navigation & Correction
setopt AUTO_CD               # Typing 'Documents' takes you there
setopt CORRECT               # Spell check for commands
setopt NO_BEEP               # Silence please

# ==============================================================================
# 4. ENVIRONMENT & LOCALES
# ==============================================================================
# Fixes 'locale' errors when connecting via SSH from macOS
#export LANG=en_US.UTF-8
#export LC_ALL=en_US.UTF-8
export EDITOR='micro'         # Use 'code' if you prefer VS Code remote
export PATH="$HOME/.local/bin:$PATH"
export HOMEBREW_NO_ENV_HINTS=1

# ==============================================================================
# 5. ALIASES (Productivity Boosters)
# ==============================================================================
alias zshrc='micro ~/.zshrc'
alias reload='source ~/.zshrc'
alias mi='micro'

# ==============================================================================
# 6. RUNTIME MANAGEMENT: MISE (The asdf successor)
# ==============================================================================
# This manages Node, Python, Go, etc. using .tool-versions files.
eval "$(mise activate zsh)"

# ==============================================================================
# 7. THE PROMPT: STARSHIP (Modern Rust Prompt)
# ==============================================================================
# This must be the very last line to ensure it renders correctly.
eval "$(starship init zsh)"

# Auto-cd to ~ when entering from macOS paths
case "$PWD" in
  /Users/*|/mnt/mac/*) cd ~ ;;
esac
