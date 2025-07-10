#!/usr/bin/env bash
###############################################################################
# 💻  setup_env.sh – Apple-silicon bleeding-edge bootstrapper                  #
#    • Headless Xcode + Rosetta install (idempotent)                           #
#    • asdf runtime manager (Node + JS/TS tools)                               #
#    • Vendor installers (no live curl|bash)                                   #
#    • Post-install version report                                             #
###############################################################################
set -euo pipefail
bold_blue() { printf "\033[1;34m%s\033[0m\n" "$*"; }

[[ $(uname -m) == arm64 ]] || {
  echo "❌  Intel Mac detected — script supports Apple Silicon only."
  exit 1
}

###############################################################################
# 1. Vendor payload verification                                               #
###############################################################################
bold_blue "▶ 1. Verifying vendor payloads…"
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
VENDOR_DIR="$SCRIPT_DIR/vendor"

ASDF_INSTALL_SCRIPT="$VENDOR_DIR/asdf/install.sh"         # latest vendored
ZIM_INSTALL_SCRIPT="$VENDOR_DIR/zim/install.zsh"          # latest vendored
HOMEBREW_INSTALL_SCRIPT="$VENDOR_DIR/homebrew/install.sh" # latest vendored
ZIMFW_SCRIPT="$VENDOR_DIR/zim/zimfw.zsh"                  # latest vendored

for f in "$ASDF_INSTALL_SCRIPT" "$ZIM_INSTALL_SCRIPT" "$HOMEBREW_INSTALL_SCRIPT" "$ZIMFW_SCRIPT"; do
  [[ -f $f ]] || {
    echo "❌  Missing vendor file: $f"
    exit 1
  }
done
echo "✅ Vendor checks passed."

###############################################################################
# 2. Backup existing dotfiles                                                  #
###############################################################################
bold_blue "▶ 2. Backing up existing dotfiles…"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.zsh_backup_$TIMESTAMP"
REPORT_FILE="$BACKUP_DIR/install_report_$TIMESTAMP.txt"
mkdir -p "$BACKUP_DIR"

for p in .zshrc .zimrc .zim .p10k.zsh .setup.zsh .dotfiles; do
  cp -a "$HOME/$p" "$BACKUP_DIR/" 2>/dev/null || true
done
cp -a "$HOME/Library/LaunchAgents/com.local.devtools-updater.plist" \
  "$BACKUP_DIR/" 2>/dev/null || true
echo "🗄️ Backup stored in $BACKUP_DIR"

###############################################################################
# 3. Core directories                                                          #
###############################################################################
bold_blue "▶ 3. Creating core directories…"
BREW_PREFIX="/opt/homebrew"
DOTFILES_DIR="$HOME/.dotfiles"
BIN_DIR="$DOTFILES_DIR/bin"
SETUP_RC="$HOME/.setup.zsh"

mkdir -p "$DOTFILES_DIR" "$DOTFILES_DIR/zsh" "$BIN_DIR"
append_if_missing() {
  local f=$1 l=$2
  grep -qxF "$l" "$f" 2>/dev/null || echo "$l" >>"$f"
}
echo "✅ Directories ready."

###############################################################################
# 4. Headless Xcode CLI & Rosetta                                             #
###############################################################################
bold_blue "▶ 4. Ensuring Xcode Command-Line Tools & Rosetta…"

if ! pkgutil --pkgs | grep -q "com.apple.pkg.RosettaUpdateAuto"; then
  sudo softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1 || true
fi

if ! xcode-select -p &>/dev/null; then
  echo "🛠 Installing Xcode CLI Tools…"
  sudo softwareupdate --install --all --agree-to-license --force
fi
xcode-select -p &>/dev/null || {
  echo "❌ Xcode tools missing — aborting."
  exit 1
}
echo "✅ Xcode tools present."

###############################################################################
# 5. Homebrew (install or update)                                              #
###############################################################################
bold_blue "▶ 5. Installing or updating Homebrew…"
if ! command -v brew &>/dev/null; then
  NONINTERACTIVE=1 bash "$HOMEBREW_INSTALL_SCRIPT" </dev/null
fi
eval "$($BREW_PREFIX/bin/brew shellenv)"
brew update
echo "✅ Homebrew ready."

###############################################################################
# 6. Remove conflicting Node/NVM formulae                                      #
###############################################################################
bold_blue "▶ 6. Cleaning old Homebrew Node stacks…"
for pkg in node node@18 node@20 nvm pnpm; do
  brew list --formula | grep -qx "$pkg" && brew uninstall --ignore-dependencies --force "$pkg"
done
echo "✅ Conflicts cleared."

###############################################################################
# 7. Core CLI tools & fonts                                                    #
###############################################################################
bold_blue "▶ 7. Installing core CLI tools…"
brew install git wget curl jq fzf gh bat ripgrep direnv
brew install --cask orbstack
brew install --cask visual-studio-code google-chrome
brew tap homebrew/cask-fonts
brew install --cask font-meslo-lg-nerd-font
brew cleanup -s
echo "✅ Core tools installed."

# ── VSCode font + default shell                                               #
bold_blue "▶ Tweaking VSCode settings…"
VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
mkdir -p "$(dirname "$VSCODE_SETTINGS")"
[[ -f $VSCODE_SETTINGS ]] || echo '{}' >"$VSCODE_SETTINGS"

tmp=$(mktemp)
jq '. + {
      "terminal.integrated.fontFamily": "MesloLGS NF",
      "terminal.integrated.defaultProfile.osx": "zsh"
    }' "$VSCODE_SETTINGS" >"$tmp" && mv "$tmp" "$VSCODE_SETTINGS"
echo "✅ VSCode terminal now uses MesloLGS NF + zsh."

###############################################################################
# 8. Runtimes via asdf (latest Node)                                           #
###############################################################################
bold_blue "▶ 8. Installing runtimes via asdf…"
ASDF_DIR="$HOME/.asdf"
[[ -x $ASDF_DIR/bin/asdf ]] || bash "$ASDF_INSTALL_SCRIPT" --no-bash --no-fish --no-zsh
. "$ASDF_DIR/asdf.sh"

if ! asdf plugin-list | grep -q "^nodejs$"; then
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git && echo "➕ Added asdf-nodejs plugin"
fi
[[ -f $ASDF_DIR/keyrings/nodejs/asc ]] || bash "$ASDF_DIR/plugins/nodejs/bin/import-release-team-keyring"

asdf install nodejs latest
asdf global nodejs latest
echo "🟢 Node $(node -v) ready (npm $(npm -v))."

corepack enable
npm install -g pnpm tsx typescript ts-node
echo "✅ Global JS/TS tooling installed."

###############################################################################
# 9. Zim framework                                                             #
###############################################################################
bold_blue "▶ 9. Setting up Zim framework…"
[[ -d $HOME/.zim ]] || zsh "$ZIM_INSTALL_SCRIPT"
cat >"$HOME/.zimrc" <<'ZIMRC'
zmodule environment input termtitle utility
zmodule zsh-users/zsh-completions completion
zmodule zsh-users/zsh-history-substring-search
zmodule Aloxaf/fzf-tab
zmodule MichaelAquilina/zsh-you-should-use
zmodule zdharma-continuum/fast-syntax-highlighting
zmodule zsh-users/zsh-autosuggestions
zmodule romkatv/powerlevel10k
zmodule fzf --on-demand
ZIMRC

mkdir -p "$HOME/.zim"
cp -f "$ZIMFW_SCRIPT" "$HOME/.zim/zimfw.zsh"
zimfw install -q && zimfw compile -q
echo "✅ Zim configured."

###############################################################################
# 10. Aliases & functions                                                      #
###############################################################################
bold_blue "▶ 10. Writing custom aliases…"
mkdir -p "$HOME/.dotfiles/zsh"

# --- Git --------------------------------------------------------------------
cat >"$HOME/.dotfiles/zsh/git.zsh" <<'EOF'
# Git aliases ------------------------------------------------------------------
alias status='git status -s'
alias branch='git branch'
alias switch='git switch'
alias switch-c='git switch -c'

alias add='git add'
alias stage='git add --all'

alias commit='git commit -m'
alias amend='git commit --amend --no-edit'

alias fetch='git fetch --prune --all'
alias rebase='git fetch origin && git rebase'

alias push='git push'
alias push-f='git push --force-with-lease'

alias gitlog='git log --oneline --graph --decorate --all'

alias reset='git reset'
alias reset-soft='git reset --soft HEAD~1'
alias reset-mixed='git reset --mixed HEAD~1'
reset-hard() { echo '⚠️ Discards all changes! Ctrl-C to cancel.'; sleep 2; git reset --hard HEAD~1; }

alias unstage='git restore --staged .'
alias discard='git restore .'
discard-all() { echo '⚠️ Nukes everything to HEAD. Ctrl-C to cancel.'; sleep 2; git reset --hard; }

alias stash='git stash push'
alias pop='git stash pop'
alias stash-list='git stash list'
alias stash-show='git stash show -p'
alias stash-drop='git stash drop'
alias stash-clear='git stash clear'
stash-save() { git stash push -m "$*"; }
EOF

# --- PNPM -------------------------------------------------------------------
cat >"$HOME/.dotfiles/zsh/pnpm.zsh" <<'EOF'
# PNPM aliases -----------------------------------------------------------------
alias pn='pnpm'
alias pni='pnpm install'
alias pna='pnpm add'
alias pna-dev='pnpm add -D'
alias pnrm='pnpm remove'
alias pnup='pnpm up --latest'

alias pnrun='pnpm run'
alias pn-script='pnpm dev:scripts'

pni-clean() { rm -rf node_modules && rm -f pnpm-lock.yaml && pnpm install; }
EOF

# --- NPM --------------------------------------------------------------------
cat >"$HOME/.dotfiles/zsh/npm.zsh" <<'EOF'
# NPM aliases ------------------------------------------------------------------
alias npmi='npm install'
alias npmi-dev='npm install --save-dev'
alias npmi-g='npm install --global'
npmi-clean() { rm -rf node_modules && npm cache clean --force && npm install; }

alias npm-run='npm run'
alias npm-start='npm run start'
alias npm-dev='npm run dev'
alias npm-test='npm test'

alias npm-rm='npm uninstall'
alias npm-up='npm update'

alias npm-ls='npm list'
alias npm-lsg='npm list --global'
EOF

# --- GitHub CLI -------------------------------------------------------------
cat >"$HOME/.dotfiles/zsh/gh.zsh" <<'EOF'
# GitHub CLI aliases -----------------------------------------------------------
alias ghs='gh auth status'
alias ghpr='gh pr create --web --fill'
alias ghco='gh pr checkout'
alias ghpv='gh pr view --web'

alias ghrl='gh run list --limit 20'
alias ghrw='gh run watch'
EOF

for f in "$HOME/.dotfiles/zsh"/*.zsh; do zcompile "$f" &>/dev/null || true; done
echo "✅ Aliases ready."

###############################################################################
# 11. Dev-tools updater                                                        #
###############################################################################
bold_blue "▶ 11. Creating dev-tools updater…"
cat >"$BIN_DIR/update-devtools" <<'EOF'
#!/usr/bin/env zsh
echo '🔄 Updating Homebrew, asdf plugins, Zim & global npm packages…'

brew update && brew upgrade && brew autoremove -s && brew cleanup -s

asdf update >/dev/null 2>&1 || true
asdf plugin-update --all >/dev/null 2>&1 || true
asdf install >/dev/null 2>&1 || true

zimfw update -q && zimfw upgrade -q

npm update -g >/dev/null 2>&1 || true
npm install -g pnpm tsx typescript ts-node >/dev/null 2>&1 || true

echo '✅ Dev tools up to date.'
EOF
chmod +x "$BIN_DIR/update-devtools"
echo "✅ Updater ready."

###############################################################################
# 12. Glue RC                                                                  #
###############################################################################
bold_blue "▶ 12. Writing main Zsh glue RC…"
cat >"$SETUP_RC" <<'EOF'
# p10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

setopt HIST_IGNORE_ALL_DUPS
bindkey -e
WORDCHARS=

export ZIM_GIT_DISABLE_ALIASES=true
export YSU_DISABLE_SHELL_GLOBBING=true

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
source $ZIM_HOME/zimfw.zsh init
source $ZIM_HOME/init.zsh

[[ -s $HOME/.asdf/asdf.sh ]] && source $HOME/.asdf/asdf.sh

autoload -Uz compinit && compinit -C

for f in $HOME/.dotfiles/zsh/*.zsh; do source "$f"; done

(( ${+functions[fast-theme]} )) && fast-theme Paradox &>/dev/null
[[ -f ~/.p10k.zsh ]] && zcompile ~/.p10k.zsh &>/dev/null || true
EOF

append_if_missing "$HOME/.zshrc" "# >>> my setup_mac.sh custom configs (do not remove)"
append_if_missing "$HOME/.zshrc" "source \"$SETUP_RC\""
append_if_missing "$HOME/.zshrc" "# <<< my setup_mac.sh custom configs"
echo "✅ RC glued into ~/.zshrc."

###############################################################################
# 13. LaunchAgent for weekly updates                                           #
###############################################################################
LA_ID="com.local.devtools-updater"

mkdir -p "$HOME/Library/LaunchAgents"
cat >"$HOME/Library/LaunchAgents/${LA_ID}.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key> <string>${LA_ID}</string>
  <key>ProgramArguments</key> <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>$BIN_DIR/update-devtools</string>
  </array>
  <key>StartCalendarInterval</key> <dict>
    <key>Weekday</key> <integer>1</integer>
    <key>Hour</key>    <integer>4</integer>
    <key>Minute</key>  <integer>0</integer>
  </dict>
  <key>StandardOutPath</key> <string>/dev/null</string>
  <key>StandardErrorPath</key><string>/dev/null</string>
</dict></plist>
EOF

launchctl unload "$HOME/Library/LaunchAgents/${LA_ID}.plist" &>/dev/null || true
launchctl load "$HOME/Library/LaunchAgents/${LA_ID}.plist"
echo "✅ Launch agent loaded as ${LA_ID}."

###############################################################################
# 14. Post-install report                                                      #
###############################################################################
bold_blue "▶ 14. Generating post-install report…"
{
  echo "🎞 Apple Silicon dev environment install report – $TIMESTAMP"
  echo "• macOS            : $(sw_vers -productVersion) ($(uname -m))"
  echo -n "• Xcode CLI        : "
  pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | awk '/version/{print $2}'
  echo "• Homebrew         : $(brew --version | head -n1)"
  echo "• Brew formulae    :"
  brew list --formula --versions | sed 's/^/   └ /'
  echo "• Orbstack version : $(orbstack --version 2>/dev/null || echo n/a)"
  echo "• Node (asdf)      : $(node -v) (npm $(npm -v), pnpm $(pnpm -v))"
  echo "• Zim modules      : $(zimfw list | paste -sd, -)"
} | tee "$REPORT_FILE"

echo "📄 Report saved at: $REPORT_FILE"
echo -e "\n✅ Dev environment ready. Open a new terminal tab; Powerlevel10k will launch its wizard."
