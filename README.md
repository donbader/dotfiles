# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) featuring a modular, self-contained app structure.

## Features

- **Modular Design**: Each app is completely self-contained with its own configuration and installation script
- **Cross-Platform**: Supports both macOS and Linux with shared configurations
- **Automated Installation**: Simple script-based installation with dependency management
- **Flexible**: Install all apps or pick and choose specific ones

## Structure

```
dotfiles/
├── install.sh              # Main installation script
├── lib/                    # Shared utilities
│   ├── utils.sh           # OS detection, logging
│   └── app-manager.sh     # App installation logic
│
└── apps/
    ├── shared/            # Cross-platform apps
    │   ├── git/
    │   ├── zsh/
    │   ├── starship/
    │   ├── fzf/
    │   ├── autojump/
    │   ├── scripts/
    │   ├── opencode/
    │   └── claude-code/
    │
    ├── macos/             # macOS-only apps
    │   ├── homebrew/
    │   ├── warp/
    │   ├── vscode/
    │   ├── brave/
    │   ├── slack/
    │   ├── orbstack/
    │   ├── fonts/
    │   ├── macos-settings/
    │   ├── gh/
    │   ├── ripgrep/
    │   ├── tig/
    │   └── vim/
    │
    └── linux/             # Linux-only apps
        └── vscode/
```

## Quick Start

### Prerequisites

**macOS:**
```bash
# Install Homebrew (will be installed automatically if missing)
./install.sh homebrew
```

**Linux:**
```bash
# Stow will be installed automatically if missing
```

### Installation

```bash
# Clone this repository
git clone <your-repo-url> ~/Projects/dotfiles
cd ~/Projects/dotfiles

# List available apps
./install.sh --list

# Install everything
./install.sh --all

# Install specific apps
./install.sh git zsh starship

# Install configs only (skip dependencies)
./install.sh --no-deps git zsh
```

## Usage

### Install Apps

```bash
# Install all apps for your OS
./install.sh --all

# Install specific apps
./install.sh git zsh starship warp

# Install without dependencies (config files only)
./install.sh --no-deps git
```

### List Available Apps

```bash
./install.sh --list
```

### Update Configurations

```bash
# Restow (update) app configurations
./install.sh --restow git zsh

# Restow all apps
./install.sh --restow --all
```

### Remove Configurations

```bash
# Unstow (remove) specific apps
./install.sh --unstow git

# Unstow all apps
./install.sh --unstow --all
```

### Dry Run

```bash
# See what would be installed without actually doing it
./install.sh --dry-run --all
./install.sh --dry-run git zsh starship
```

## App Structure

Each app is self-contained in its own directory:

### Shared Apps (Cross-Platform)

```
apps/shared/git/
├── install-macos.sh        # macOS installation script
├── install-linux.sh        # Linux installation script
├── .gitconfig              # Stowed to ~/.gitconfig
├── .gitignore              # Stowed to ~/.gitignore
└── .config/zsh/git.zsh     # Stowed to ~/.config/zsh/git.zsh
```

### OS-Specific Apps

```
apps/macos/warp/
├── install.sh              # Installation script
└── .config/warp/...        # Stowed to ~/.config/warp/
```

## Available Apps

### Shared (Cross-Platform)

- **git** - Git configuration and aliases
- **zsh** - Zsh shell with Zim framework
- **starship** - Cross-shell prompt
- **fzf** - Fuzzy finder
- **autojump** - Smart directory navigation
- **scripts** - Custom utility scripts (otp, sshcode, vpn-connect, etc.)
- **opencode** - OpenCode AI assistant configuration
- **claude-code** - Claude Code aliases

### macOS Only

- **homebrew** - Homebrew package manager
- **warp** - Warp terminal
- **vscode** - Visual Studio Code settings
- **brave** - Brave browser
- **slack** - Slack
- **orbstack** - OrbStack (Docker/Linux)
- **fonts** - Nerd Fonts
- **macos-settings** - System preferences (trackpad, keyboard, etc.)
- **gh** - GitHub CLI
- **ripgrep** - Fast grep alternative
- **tig** - Text-mode interface for git
- **vim** - Vim editor

## Adding a New App

### 1. Create App Directory

```bash
# For cross-platform app
mkdir -p apps/shared/myapp

# For macOS-only app
mkdir -p apps/macos/myapp
```

### 2. Add Configuration Files

```bash
# Add your dotfiles
apps/shared/myapp/
├── .config/myapp/config.yml
└── .myapprc
```

### 3. Create Installation Script (Optional)

**For shared apps** - create both OS-specific scripts:

```bash
# apps/shared/myapp/install-macos.sh
#!/bin/bash
brew install myapp

# apps/shared/myapp/install-linux.sh
#!/bin/bash
sudo apt install -y myapp
```

**For OS-specific apps** - create single install script:

```bash
# apps/macos/myapp/install.sh
#!/bin/bash
brew install --cask myapp
```

### 4. Install It

```bash
./install.sh myapp
```

## How It Works

1. **OS Detection**: Automatically detects macOS or Linux
2. **App Discovery**: Scans `apps/shared/` and `apps/{os}/` for available apps
3. **Dependency Installation**: Runs `install.sh` or `install-{os}.sh` if present
4. **Configuration Stowing**: Symlinks config files to `$HOME` using GNU Stow
5. **Selective Installation**: Install all apps or specific ones

## Typical macOS Setup

```bash
# 1. Install Homebrew (required first)
./install.sh homebrew

# 2. Install essential tools
./install.sh git zsh starship fzf autojump

# 3. Install applications
./install.sh warp vscode brave slack orbstack

# 4. Install utilities
./install.sh gh ripgrep tig vim fonts

# 5. Configure custom scripts
./install.sh scripts opencode claude-code

# 6. Apply system settings
./install.sh macos-settings
```

## Notes

- All `install*.sh` scripts are ignored by stow (won't be symlinked)
- Shared apps are checked first, then OS-specific apps
- If an app exists in both shared and OS-specific, shared takes precedence
- The `.stowrc` file configures stow to target `$HOME` and adopt existing files
- Each app can be installed/uninstalled independently

## Custom Scripts

The `scripts` app includes several useful utilities:

- **otp** - Secure OTP/TOTP manager with encryption
- **sshcode** - Interactive SSH host selector for VS Code Remote
- **vpn-connect** - Pritunl VPN connection helper with OTP integration
- **vpn-disconnect** - Pritunl VPN disconnection helper

Scripts are installed to `~/scripts/bin/` and automatically added to PATH.

## Troubleshooting

### Stow conflicts

If stow reports conflicts, you can:

```bash
# Adopt existing files (merge with dotfiles)
stow --adopt <app-name>

# Or remove conflicting files first
rm ~/.gitconfig
./install.sh git
```

### Permission issues

Some apps may require sudo access for installation. The install scripts will prompt when needed.

### Shell not changing

After installing zsh:

```bash
# Logout and login again, or manually switch
exec zsh
```

## License

MIT
