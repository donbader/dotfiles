# Zsh Modular Configuration System

This directory contains a three-stage initialization system for modular zsh configuration.

## Directory Structure

```
~/.config/zsh/
├── pre-init/    # Stage 1: Before everything (optional)
├── init/        # Stage 2: Main initialization (optional)
└── post-init/   # Stage 3: After everything (optional)
```

**Each app creates only the directories it needs.** If an app doesn't need a specific stage, it simply doesn't create that directory.

## Execution Order

1. **pre-init/** - Runs FIRST, before all init
   - Use when you need to stub/modify functions before frameworks load
   - Example: Flox compinit stub

2. **init/** - Main initialization stage
   - Most configs go here
   - Includes core options, PATH setup, zim initialization
   - Files load alphabetically, use numbered prefixes to control order

3. **post-init/** - Runs LAST, after all init
   - Use for things that depend on init being complete
   - Example: P10k instant prompt, keybindings, aliases

## Example: App Structure

### Simple app (most common)
```
apps/shared/git/.config/zsh/
└── init/
    └── git.zsh              # Just needs init stage
```

### Complex app with hooks
```
apps/shared/flox/.config/zsh/
├── pre-init/
│   └── flox.zsh            # Stub compinit before zim
├── init/
│   └── flox.zsh            # Main config
└── post-init/
    └── flox.zsh            # Restore compinit after zim
```

### Core zsh config
```
apps/shared/zsh/.config/zsh/
├── pre-init/
│   └── .gitkeep            # Empty, no pre-init needed
├── init/
│   ├── 00-options.zsh      # Load first
│   ├── path.zsh            # Regular init
│   └── 99-zim.zsh          # Load last (zim initialization)
└── post-init/
    └── alias.zsh           # Aliases loaded at the end
```

## Adding New Apps

When creating a new app with stow, create only the directories you need:

### Most apps (just need init):
```bash
mkdir -p apps/shared/myapp/.config/zsh/init
echo '# My app config' > apps/shared/myapp/.config/zsh/init/myapp.zsh
```

### Apps needing pre-init:
```bash
mkdir -p apps/shared/myapp/.config/zsh/pre-init
echo '# Run before init' > apps/shared/myapp/.config/zsh/pre-init/myapp.zsh
```

### Apps needing post-init:
```bash
mkdir -p apps/shared/myapp/.config/zsh/post-init
echo '# Run after init' > apps/shared/myapp/.config/zsh/post-init/myapp.zsh
```

## When to Use Each Stage

### pre-init/
- Stub or modify functions that init will call
- Set environment variables that affect init behavior
- **Rarely needed** - only for special cases like flox

### init/
- **Use this for 99% of configs**
- PATH modifications
- Environment variables
- Function definitions
- Application initialization

### post-init/
- Keybindings (after zsh plugins loaded)
- Aliases (to override anything from init)
- Instant prompts (after theme loaded)
- Things that depend on init being complete
