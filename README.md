# 🍏 Mac Bootstrap Kit

> **Bleeding‑edge setup for Apple‑silicon Macs** -- no versions are pinned; every run fetches the latest Homebrew bottles, Node LTS, Zim modules and npm globals.

Two scripts ship your machine from zero to _code‑ready_ in minutes:

| File                   | Purpose                                                                                                                                                                                               | Typical first‑run time            |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| **`setup_env_mac.sh`** | Installs Xcode CLI, Homebrew, fonts, GUI apps (VS Code, Chrome, Orbstack), latest Node via **asdf**, global JS/TS tooling, Zim framework+Powerlevel10k, and a weekly self‑updater (`launchd`).        |  ≈ 15 min (Xcode & brew bottling) |
| **`setup_ssh_git.sh`** | Configures your Git author, sensible Git defaults, generates a secure *ed25519* key, loads it into Keychain, authenticates with GitHub via **gh**, uploads the key, and writes a global `.gitignore`. |  < 30 s                           |

---

## 📂 Repo layout

```
mac-bootstrap-kit/
├─ setup_env_mac.sh      # Dev‑environment bootstrapper
├─ setup_ssh_git.sh      # Git & GitHub SSH helper
├─ vendor/               # SHA‑pinned installer stubs (no curl|bash at runtime)
│   ├─ asdf/install.sh
│   ├─ homebrew/install.sh
│   └─ zim/...
└─ README.md             # (this file)

```

---

## 🚀 Quick‑start

```
# 1 clone & cd
git clone https://github.com/<you>/mac-bootstrap-kit.git
cd mac-bootstrap-kit

# 2 bootstrap the environment (one sudo prompt for softwareupdate)
bash setup_env_mac.sh

# 3 open a new terminal tab -- Powerlevel10k runs its wizard

# 4 configure Git + GitHub SSH (no prompts if GIT_NAME / GIT_EMAIL set)
bash setup_ssh_git.sh

```

### Customising Git identity upfront

```
GIT_NAME="Ada Lovelace"\
GIT_EMAIL="ada@lovelace.dev"\
bash setup_ssh_git.sh

```

---

## 🛠 What gets installed?

- **Xcode Command‑Line Tools** *(headless)* + Rosetta (if missing)

- **Homebrew** core formulae: `git`, `jq`, `gh`, `fzf`, `ripgrep`, `direnv`, `bat`, ...

- **GUI casks**: VS Code, Google Chrome, Orbstack, MesloLGS NF font

- **asdf** runtime manager → latest **Node LTS**

- Global npm tools: `pnpm`, `tsx`, `typescript`, `ts-node`

- **Zim framework** with fzf‑tab, autosuggestions, fast‑syntax‑highlighting, Powerlevel10k

- **LaunchAgent** -- weekly `update-devtools` Monday 04:00

- **Post‑install report** at `~/.zsh_backup_<timestamp>/install_report_*.txt`

Git/SSH script adds:

- Git defaults: `push.autoSetupRemote=true`, `pull.rebase=true`, `init.defaultBranch=main`

- Single **ed25519** key autoloaded into Keychain & GitHub

- Global `.gitignore` for editor & OS cruft

---

## 🔄 Updating

The launch agent keeps Homebrew, Zim, asdf plugins & npm globals fresh.\
Trigger manually any time:

```
update-devtools

```

---

## ♻️ Rollback / Uninstall

Every run snapshots your old dotfiles under `~/.zsh_backup_<timestamp>/`.\
Restore by copying files back, or remove created artefacts:

```
rm -rf ~/.dotfiles ~/.zim ~/.asdf\
       ~/Library/LaunchAgents/com.local.devtools-updater.plist

```

Remove Homebrew packages individually via `brew uninstall`.

---

## ☁️ Backups

- **GitHub** -- commit this repo (including `vendor/`) to keep a versioned copy.

- **Google Drive / iCloud** -- sync the entire folder for off‑site redundancy.

---

## 📄 License

MIT -- free to use, modify, and share. No warranties.

---

### ✨ Happy hacking!
