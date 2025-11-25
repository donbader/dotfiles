# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Structure

Each directory is a "package" that can be installed independently:

- **autojump** - Directory navigation shortcuts
- **fzf** - Fuzzy finder configuration
- **git** - Git configuration and aliases
- **opencode** - OpenCode AI assistant configuration
- **scripts** - Custom utility scripts
- **starship** - Cross-shell prompt configuration
- **vscode** - Visual Studio Code settings
- **zsh** - Zsh configuration using Zim framework

## Installation

### Prerequisites

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Stow
brew install stow
```

### Setup

1. Clone this repository:
```bash
git clone <repository-url> ~/Projects/dotfiles
cd ~/Projects/dotfiles
```

2. Install packages using stow:
```bash
# Install all packages
stow */

# Or install specific packages
stow zsh git scripts starship
```

3. Reload your shell:
```bash
source ~/.zshrc
```

## Package Details

### zsh
Zsh configuration with [Zim framework](https://github.com/zimfw/zimfw) for fast plugin management.

**Features:**
- Auto-suggestions and syntax highlighting
- History substring search
- Custom aliases and functions

**Installs:**
- `~/.zshrc`
- `~/.zimrc`
- `~/.config/zsh/alias.zsh`

### scripts
Custom utility scripts with separate `bin/` and `data/` directories.

**Available scripts:**
- `otp` - Secure OTP/TOTP manager with encryption
- `sshcode` - Interactive SSH host and directory selector for VS Code Remote
- `vpn-connect` - Pritunl VPN connection helper with OTP integration
- `vpn-disconnect` - Pritunl VPN disconnection helper

**Installs:**
- `~/scripts/bin/*` (added to PATH)
- `~/scripts/data/otp_secrets.enc`
- `~/.config/zsh/scripts.zsh`

#### OTP Script
Secure OTP manager with AES-256-GCM encryption and macOS Keychain integration.

```bash
# Add a new OTP secret
otp add github JBSWY3DPEHPK3PXP

# Get current OTP code
otp get github

# List all services
otp list
```

### git
Git configuration and zsh integration.

**Installs:**
- `~/.gitconfig`
- `~/.gitignore`
- `~/.config/zsh/git.zsh`

### starship
Beautiful cross-shell prompt with custom theme.

**Installs:**
- `~/.config/starship.toml`
- `~/.config/zsh/starship.zsh`

**Install starship:**
```bash
brew install starship
```

### fzf
Fuzzy finder configuration for command-line.

**Installs:**
- `~/.config/zsh/fzf.zsh`

**Install fzf:**
```bash
brew install fzf
```

### autojump
Smart directory navigation that learns your habits.

**Installs:**
- `~/.config/zsh/autojump.zsh`

**Install autojump:**
```bash
brew install autojump
```

### vscode
Visual Studio Code settings.

**Installs:**
- `~/Library/Application Support/Code/settings.json`

### opencode
OpenCode AI assistant custom commands.

**Installs:**
- `~/.config/opencode/opencode.json`
- `~/.config/opencode/command/*.md`

## Updating

```bash
cd ~/Projects/dotfiles
git pull

# Re-stow packages to pick up changes
stow -R */
```

## Uninstalling

```bash
cd ~/Projects/dotfiles

# Remove all packages
stow -D */

# Or remove specific packages
stow -D zsh git scripts
```

## How Stow Works

Stow creates symlinks from the package directories to your home directory:
- Files in `package/.config/` → `~/.config/`
- Files in `package/scripts/` → `~/scripts/`
- Files in `package/.zshrc` → `~/.zshrc`

The `.stowrc` file configures stow to:
- Target `$HOME` directory
- Adopt existing files
- Ignore certain files like `.stowrc` and `install.sh`

## Notes

- All scripts in `~/scripts/bin/` are automatically added to PATH
- OTP secrets are encrypted with AES-256-GCM and safe to commit
- Zsh configuration sources all `~/.config/zsh/*.zsh` files automatically
- Each package can be installed/uninstalled independently
