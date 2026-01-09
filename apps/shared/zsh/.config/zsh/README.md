# Zsh Modular Configuration System

A three-stage initialization system for modular zsh configuration using GNU Stow.

## How It Works

Configuration files from multiple apps are symlinked into `~/.config/zsh/` and loaded in three stages:

```
~/.config/zsh/
├── pre-init/    # Stage 1: Before everything (optional)
├── init/        # Stage 2: Main initialization (optional)
└── post-init/   # Stage 3: After everything (optional)
```

**Apps create only the directories they need.** Most apps only use `init/`, with `pre-init/` and `post-init/` reserved for special cases.

## Execution Order

Files within each stage load alphabetically. Use numbered prefixes (e.g., `00-`, `99-`) to control load order within a stage.

### 1. pre-init/ - Setup Hooks
**Rarely needed.** Use only when you need to intercept or modify behavior before main initialization.

Use cases:
- Stub functions that will be called during init
- Set variables that affect initialization behavior
- Install wrappers around system functions

### 2. init/ - Main Configuration
**Use this for 99% of your configs.** Standard configuration stage for most applications.

Use cases:
- PATH modifications
- Environment variables
- Function definitions
- Application initialization
- Plugin/framework loading

### 3. post-init/ - Finalization
Use for configuration that depends on init being complete or needs to override init settings.

Use cases:
- Keybindings (after plugins are loaded)
- Aliases (to override init definitions)
- Prompt finalization
- Completion system modifications
- Interactive shell enhancements

## Directory Structure Examples

### Minimal (Most Common)
```
apps/shared/myapp/.config/zsh/
└── init/
    └── config.zsh
```

### With Post-Init
```
apps/shared/myapp/.config/zsh/
├── init/
│   └── config.zsh
└── post-init/
    └── config.zsh
```

### Complete Three-Stage
```
apps/shared/myapp/.config/zsh/
├── pre-init/
│   └── config.zsh
├── init/
│   └── config.zsh
└── post-init/
    └── config.zsh
```

### Controlling Load Order
```
apps/shared/myapp/.config/zsh/init/
├── 00-early.zsh
├── config.zsh
└── 99-late.zsh
```

## Creating New App Configs

Create only the directories your app needs:

### Basic app (most common):
```bash
mkdir -p apps/shared/myapp/.config/zsh/init
cat > apps/shared/myapp/.config/zsh/init/config.zsh << 'EOF'
# App configuration
export MYAPP_HOME="$HOME/.myapp"
alias myapp="command myapp"
EOF
```

### With post-init:
```bash
mkdir -p apps/shared/myapp/.config/zsh/{init,post-init}
echo '# Main config' > apps/shared/myapp/.config/zsh/init/config.zsh
echo '# Keybindings' > apps/shared/myapp/.config/zsh/post-init/config.zsh
```

### With pre-init (rare):
```bash
mkdir -p apps/shared/myapp/.config/zsh/{pre-init,init}
echo '# Setup hook' > apps/shared/myapp/.config/zsh/pre-init/config.zsh
echo '# Main config' > apps/shared/myapp/.config/zsh/init/config.zsh
```

## Decision Guide

Choose your stage based on dependencies:

| Question | Stage |
|----------|-------|
| Standard configuration? | **init/** |
| Need to intercept/modify init behavior? | **pre-init/** |
| Depends on init being complete? | **post-init/** |
| Keybindings after plugins load? | **post-init/** |
| Aliases that override init settings? | **post-init/** |
| Not sure? | **init/** (default) |
