# Mac Bootstrap Kit

**Personal one‑shot installers for my Apple‑silicon Mac.**  Nothing here is version‑pinned on purpose – every run grabs the freshest tools available.

| Script             | Purpose                                                                                             | 1st‑run ⌚                       | Re‑run ⌚                      |
| ------------------ | --------------------------------------------------------------------------------------------------- | ------------------------------- | ----------------------------- |
| `setup_env_mac.sh` | End‑to‑end dev‑environment (Homebrew, asdf, Node, CLI apps, Zim + P10k, VS Code + font)             | \~15 min (Xcode & Brew)         | < 30 s (mostly `brew update`) |
| `setup_ssh_git.sh` | Configure global Git identity, create & upload SSH key, set Git defaults, write global `.gitignore` | \~25 s (1st key + browser auth) | < 2 s (no‑ops)                |

> ⚠️ **Scope** – these scripts suit **my** laptop only. They hard‑code personal paths, schedules, and bleeding‑edge behaviour.

---

## Folder layout

```
mac-bootstrap-kit/
├── setup_env_mac.sh   # dev‑environment bootstrapper
├── setup_ssh_git.sh   # Git + GitHub SSH helper
├── vendor/            # SHA‑pinned installer stubs (no curl|bash)
│   ├── asdf/install.sh
│   ├── homebrew/install.sh
│   └── zim/ …
└── README.md          # (this file)
```

---

## Quick start

```bash
# clone wherever you keep dotfiles/backups
git clone git@github.com:felipesantos94/mac-bootstrap-kit.git
cd mac-bootstrap-kit

# run the environment bootstrap – asks for sudo once for softwareupdate
bash setup_env_mac.sh

# open a **new** terminal tab to start the P10k wizard
```

### Prerequisites

- Apple‑silicon Mac (arm64) running macOS Sequoia or newer.
- Internet connection fast enough for \~1 GB Xcode CLI download.
- Browser for the one‑time **gh auth login** step.

---

## What happens – step by step

### `setup_env_mac.sh`

1. **Validate vendor stubs** (`vendor/…/install.sh`).\
   No remote *curl | bash* – inspected once, reused forever.
2. **Snapshot** existing Zsh & dotfiles into `~/.zsh_backup_YYYYMMDD_HHMMSS/`.
3. **Headless Xcode + Rosetta** via `softwareupdate`. Skips if already present.
4. **Homebrew** (install or update).
5. Remove any Homebrew `node` / `nvm` formulae to avoid path clashes.
6. Install core CLI apps: `git`, `jq`, `gh`, `fzf`, `ripgrep`, `direnv`, etc.\
   Casks: **Orbstack**, **Visual Studio Code**, **Google Chrome**, **MesloLGS NF**.
7. **VS Code settings** patched → Meslo font + default zsh profile.
8. **asdf** → latest Node LTS.\
   Enables `corepack`, installs global `pnpm`, `tsx`, `typescript`, `ts-node`.
9. **Zim** with plugins (fzf‑tab, autosuggestions, fast‑syntax‑highlighting, P10k). Compiled for fast shell startup.
10. Modular alias files (`git.zsh`, `npm.zsh`, `pnpm.zsh`, `gh.zsh`).
11. **update-devtools** script + `launchd` agent (`com.local.devtools-updater`) – runs Mondays 04:00.
12. Glue RC injected into `~/.zshrc` (loads asdf, Zim, aliases, P10k).
13. Plain‑text **install report** saved next to the backup.

### `setup_ssh_git.sh`

1. Configure `user.name` / `user.email` and sensible Git defaults:
   - `init.defaultBranch main`
   - `push.autoSetupRemote true`
   - `pull.rebase true`
   - `rebase.autoStash true`
2. Create `~/.ssh/` (700) + *ed25519* key (if absent).
3. Ensure **one** `ssh-agent` instance; load key into macOS Keychain.
4. `gh auth login` (browser) only if token missing/expired.
5. Upload key via `gh ssh-key add` – JSON detection avoids truncated grep.
6. Write `~/.gitignore_global` (IDEs, OS cruft, logs, caches).

---

## Performance notes

| Phase                    | Cold run     | Subsequent runs       |
| ------------------------ | ------------ | --------------------- |
| Xcode CLI download       | \~7‑10 min   | 0 s (cached)          |
| Homebrew install         | \~3 min      | \~8 s (`brew update`) |
| Zim compile              | \~15 s       | 0 s                   |
| Total `setup_env_mac.sh` | **≈ 15 min** | **< 30 s**            |
| Total `setup_ssh_git.sh` | **≈ 25 s**   | **< 2 s**             |

Shell startup (`zsh -l`) stays around **60–80 ms** thanks to compiled functions & minimal plugin set.

---

## Updating manually

```bash
update-devtools   # (function auto‑loaded in every shell)
```

Runs: `brew upgrade`, `asdf plugin-update`, `zimfw upgrade`, `npm update -g`.

---

## Rollback / uninstall

- Restore dotfiles: `cp -a ~/.zsh_backup_<timestamp>/* ~` and restart Terminal.
- Remove launch agent: `launchctl remove com.local.devtools-updater`.
- Optionally `rm -rf ~/.dotfiles ~/.zim ~/.asdf`.

---
