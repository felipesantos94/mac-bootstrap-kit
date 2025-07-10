#!/usr/bin/env bash
###############################################################################
# 🔐  setup_ssh_git.sh – zero-prompt Git & GitHub SSH bootstrapper     #
###############################################################################
# • Sets global git author                                                     #
# • Applies git defaults:                                                      #
#       push.autoSetupRemote=true, pull.rebase=true, init.defaultBranch=main   #
# • Generates ed25519 key (permissions-safe)                                   #
# • Starts one ssh-agent & loads key into macOS keychain                       #
# • Authenticates with GitHub and uploads key if absent                        #
# • Creates ~/.gitignore_global and wires it into git                          #
###############################################################################

set -euo pipefail
log() { printf "\033[1;34m▶\033[0m %s\n" "$*"; }

###############################################################################
# 1. Git identity & sane defaults                                              #
###############################################################################
GIT_NAME="${GIT_NAME:-felipesantos94}"
GIT_EMAIL="${GIT_EMAIL:-felipe.fars94@gmail.com}"

log "Configuring git author → \"$GIT_NAME <$GIT_EMAIL>\""
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

log "Setting git defaults (auto-upstream, rebase pull, main branch)…"
git config --global init.defaultBranch main
git config --global push.autoSetupRemote true # Git ≥ 2.38
git config --global pull.rebase true
git config --global rebase.autoStash true

###############################################################################
# 2. SSH key generation (ed25519)                                              #
###############################################################################
KEY_PATH="$HOME/.ssh/id_ed25519"
[[ -d $HOME/.ssh ]] || {
    mkdir "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
}

if [[ -f $KEY_PATH ]]; then
    log "SSH key already exists → $KEY_PATH"
else
    log "Generating new ed25519 key…"
    ssh-keygen -q -t ed25519 -C "$GIT_EMAIL" -f "$KEY_PATH" -N ""
fi

###############################################################################
# 3. ssh-agent (single instance) & keychain                                    #
###############################################################################
_NEED_AGENT=false
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    _NEED_AGENT=true
elif ! ssh-add -l &>/dev/null; then
    # Stale socket: agent died but env var lingers
    unset SSH_AUTH_SOCK SSH_AGENT_PID
    _NEED_AGENT=true
fi

if $_NEED_AGENT; then
    log "Starting ssh-agent and loading key…"
    eval "$(ssh-agent -s)" >/dev/null
fi
ssh-add --apple-use-keychain "$KEY_PATH" 2>/dev/null || ssh-add "$KEY_PATH"

###############################################################################
# 4. GitHub authentication                                                     #
###############################################################################
if ! gh auth status -t &>/dev/null; then
    log "Logging in to GitHub (browser will open)…"
    gh auth login --hostname github.com --git-protocol ssh --web
fi

###############################################################################
# 5. Upload key to GitHub if not present                                       #
###############################################################################
PUB_KEY_CONTENT=$(awk '{print $2}' "$KEY_PATH.pub")
if gh ssh-key list --json key --jq '.[].key' | grep -q "$PUB_KEY_CONTENT"; then
    log "SSH key already registered on GitHub — skipping upload."
else
    TITLE="$(hostname)-$(date +%F)"
    log "Uploading SSH key to GitHub as \"$TITLE\"…"
    gh ssh-key add "$KEY_PATH.pub" --title "$TITLE"
fi

###############################################################################
# 6. Global .gitignore                                                         #
###############################################################################
IGNORE_FILE="$HOME/.gitignore_global"
if [[ ! -f $IGNORE_FILE ]]; then
    log "Creating global .gitignore → $IGNORE_FILE"
    cat >"$IGNORE_FILE" <<'EOF'
# ===================================================================
# Global .gitignore
# ===================================================================

# --- IDEs and Code Editors ---

# JetBrains IDEs
.idea/
*.iml
*.iws

# VSCode & Cursor
.vscode/
.cursor/
.cursor-server/
*.code-workspace

# Vim
*.[swp]
*.[swo]
*~
*.swp
*.swo

# --- Operating System Files ---

# macOS
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes
__MACOSX

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini
$RECYCLE.BIN/
NTUSER.DAT*

# --- Logs & Local Configurations ---

*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

.env
.env.local
.env.*.local

# --- Dependency & Build Caches ---

.npm/
.pnpm-store/
EOF
else
    log "Global .gitignore already exists — leaving it untouched."
fi

git config --global core.excludesfile "$IGNORE_FILE"

echo -e "\n✅  Git + SSH + GitHub setup complete. New branches auto-track origin and pulls rebase by default."
