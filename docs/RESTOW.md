# Syncing Dotfiles After Changes

When you make structural changes to your dotfiles (like reorganizing directories), you need to restow apps to update the symlinks.

## Quick Commands

### Restow a single app
```bash
./install.sh --restow zsh
./install.sh --restow git
```

### Restow all apps (after major restructure)
```bash
./install.sh --restow --all
```

### Dry run (see what would be restowed)
```bash
./install.sh --dry-run --restow --all
```

## What does restow do?

`--restow` uses `stow -R` which:
1. Removes old symlinks
2. Creates new symlinks with the updated structure

It's safe and idempotent - you can run it multiple times without issues.

## When to use restow

- After reorganizing config file structure (like moving from `zsh/*.zsh` to `zsh/init/*.zsh`)
- After renaming files in your apps
- After adding new hook directories (pre-init, init, post-init)
- When symlinks are broken or pointing to wrong locations

## Example Workflow

```bash
# 1. Make changes to your dotfiles structure
cd apps/shared/myapp
mkdir .config/zsh/init
mv .config/zsh/myapp.zsh .config/zsh/init/

# 2. Restow the app to update symlinks
cd ~/Projects/dotfiles
./install.sh --restow myapp

# 3. Test
source ~/.zshrc
```

## Troubleshooting

If restow fails:
```bash
# Option 1: Unstow and reinstall
./install.sh --unstow myapp
./install.sh myapp

# Option 2: Manual cleanup
rm ~/.config/zsh/myapp.zsh  # Remove broken symlink
./install.sh --restow myapp
```
