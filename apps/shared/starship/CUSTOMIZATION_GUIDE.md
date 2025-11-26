# Starship Prompt Customization Guide

This guide explains how to customize the Starship prompt configuration, including modifying colors, adding custom modules, and understanding the gradient system.

## Table of Contents
1. [Understanding the Configuration Structure](#understanding-the-configuration-structure)
2. [How Colors Work](#how-colors-work)
3. [Modifying the Gradient](#modifying-the-gradient)
4. [Adding/Modifying Custom Modules](#addingmodifying-custom-modules)
5. [Common Customization Tasks](#common-customization-tasks)

---

## Understanding the Configuration Structure

The Starship configuration has three main sections:

### 1. Format String (Layout)
```toml
format = """
[](color_line_1)\
$sudo\
$git_branch\
[](bg:color_line_2 fg:color_line_1)\
$git_commit\
...
"""
```

**Key concepts:**
- `$module_name` - Inserts a module (e.g., `$git_branch`, `$directory`)
- `${custom.name}` - Inserts a custom module (requires curly braces for dotted names)
- `[](bg:color_x fg:color_y)` - Powerline separator (changes background from color_y to color_x)
- Backslash `\` at end of line continues to next line
- Order in format string = order modules appear in prompt

### 2. Palette (Color Definitions)
```toml
[palettes.teal_gradient]
color_line_1 = '#0f2027'
color_line_2 = '#152830'
...
```

### 3. Module Configurations
```toml
[git_branch]
symbol = ""
style = "bg:color_line_1"
format = '[[ $symbol $branch ](fg:color_fg0 bg:color_line_1)]($style)'
```

---

## How Colors Work

### Color Assignment Rules

**CRITICAL: Each module must specify its background color in TWO places:**

1. **In the module's `style` field:**
   ```toml
   [git_branch]
   style = "bg:color_line_1"
   ```

2. **In the module's `format` field:**
   ```toml
   format = '[[ $symbol $branch ](fg:color_fg0 bg:color_line_1)]($style)'
   ```

**Both must use the same color variable!** If they don't match, the gradient will break.

### Foreground vs Background Colors

- `fg:color_name` - Text color
- `bg:color_name` - Background color
- `color_fg0 = '#ffffff'` - Usually white text
- `color_fg1 = '#000000'` - Usually black text

### Powerline Separators

The  character creates smooth transitions between sections:
```toml
[](bg:color_line_2 fg:color_line_1)
```
This means:
- Current section background = `color_line_2`
- Previous section background = `color_line_1`
- The  will be colored `color_line_1` and sit on `color_line_2` background

**Rule:** Always put separator BEFORE the module that uses the new color.

---

## Modifying the Gradient

### Step 1: Choose Your Base Colors

Find a gradient you like (e.g., from [uigradients.com](https://uigradients.com)) and note the hex colors.

Example: "Deep Sea Space" gradient
```css
linear-gradient(to right, #0f2027, #203a43, #2c5364)
```

### Step 2: Calculate Intermediate Steps

For a 10-module gradient, you need 10 colors. Calculate evenly-spaced steps between your base colors.

**Example calculation:**
- Start: `#0f2027`
- Middle: `#203a43`
- End: `#2c5364`

Break into 10 steps:
```toml
color_line_1 = '#0f2027'  # Start
color_line_2 = '#152830'  # +1 step
color_line_3 = '#1b3139'  # +2 steps
color_line_4 = '#203a43'  # Middle (original)
color_line_5 = '#24434b'  # +1 step from middle
color_line_6 = '#284c54'  # +2 steps
color_line_7 = '#2c5364'  # End (original)
color_right_1 = '#35616f' # Continue beyond
color_right_2 = '#3e6f7a' # ...
color_right_3 = '#477d85' # Lightest
```

### Step 3: Update the Palette

Edit the `[palettes.teal_gradient]` section:
```toml
[palettes.teal_gradient]
color_fg0 = '#ffffff'
color_fg1 = '#000000'
# Your gradient colors here
color_line_1 = '#0f2027'
color_line_2 = '#152830'
# ... etc
color_green = '#98971a'  # For git additions
color_red = '#cc241d'    # For git deletions
color_purple = '#b16286' # For special states
```

### Step 4: Map Colors to Modules

Decide which module gets which color. Current mapping:
- `color_line_1` → git_branch
- `color_line_2` → git_commit, git_state
- `color_line_3` → git_status, custom.git_metrics_workdir
- `color_line_4` → directory
- `color_line_5` → memory_usage
- `color_line_6` → jobs
- `color_line_7` → docker_context, kubernetes, aws
- `color_right_1` → os
- `color_right_2` → username
- `color_right_3` → time

### Step 5: Update Module Configurations

For each module, ensure both `style` and `format` use the correct color:

```toml
[directory]
style = "fg:color_fg0 bg:color_line_4"
format = "[ $path ]($style)"
```

---

## Adding/Modifying Custom Modules

### Understanding Custom Modules

Custom modules execute shell commands and display the output. They're useful when built-in modules don't meet your needs.

### Example: Git Metrics Custom Module

Our custom module shows `+additions -deletions` for uncommitted changes only:

```toml
[custom.git_metrics_workdir]
command = """git diff --numstat 2>/dev/null | awk '{added+=$1; deleted+=$2} END {if (added > 0 || deleted > 0) {if (added > 0) printf "\\033[38;2;152;151;26m+%d\\033[39m", added; if (added > 0 && deleted > 0) printf " "; if (deleted > 0) printf "\\033[38;2;204;36;29m-%d\\033[39m", deleted; printf " "}}'"""
when = "git rev-parse --is-inside-work-tree 2>/dev/null"
format = "[[$output](fg:color_fg0 bg:color_line_3)]($style)"
style = "bg:color_line_3"
description = "Show git diff stats for working directory with colors"
```

### Custom Module Anatomy

**Required fields:**
- `command` - Shell command to execute
- `format` - How to display the output (use `$output` variable)

**Optional fields:**
- `when` - Condition to check before running (return code 0 = run)
- `style` - Default styling
- `description` - Human-readable description
- `shell` - Shell to use (defaults to system shell)

### Adding Colors to Custom Module Output

Since custom modules output raw text, you have two options:

#### Option 1: Use ANSI Escape Codes (Recommended for multi-color output)

```bash
# Green text: \033[38;2;R;G;Bm
# Red text: \033[38;2;R;G;Bm
# Reset foreground: \033[39m
# Reset all: \033[0m

printf "\\033[38;2;152;151;26m+%d\\033[39m" $added  # Green
printf "\\033[38;2;204;36;29m-%d\\033[39m" $deleted # Red
```

**Important:** Use `\033[39m` (reset foreground only) NOT `\033[0m` (reset all) to preserve background colors!

#### Option 2: Use Starship Format Styling (Single color only)

```toml
format = "[[$output](fg:color_green bg:color_line_3)]($style)"
```

This applies one color to the entire output.

### Adding a Custom Module to the Prompt

1. **Define the module** in your config:
   ```toml
   [custom.my_module]
   command = "echo 'Hello'"
   format = "[[$output](fg:color_fg0 bg:color_line_5)]($style)"
   style = "bg:color_line_5"
   ```

2. **Add to format string** (use `${custom.name}` syntax):
   ```toml
   format = """
   [](color_line_1)\
   $git_branch\
   ${custom.my_module}\
   ...
   """
   ```

3. **Add separator** before your module if it uses a different color:
   ```toml
   [](fg:color_line_4 bg:color_line_5)\
   ${custom.my_module}\
   ```

### Testing Custom Modules

Test your command in the terminal first:
```bash
cd /path/to/git/repo
git diff --numstat 2>/dev/null | awk '{added+=$1; deleted+=$2} END {if (added > 0 || deleted > 0) print "+" added " -" deleted}'
```

Once working, add to Starship config.

---

## Common Customization Tasks

### Task 1: Change the Order of Modules

Edit the `format` string. Example - move directory before git info:

**Before:**
```toml
format = """
[](color_line_1)\
$git_branch\
[](fg:color_line_1 bg:color_line_4)\
$directory\
```

**After:**
```toml
format = """
[](color_line_4)\
$directory\
[](fg:color_line_4 bg:color_line_1)\
$git_branch\
```

**Remember:** Update separators to match the new color order!

### Task 2: Hide a Module

Set `disabled = true` in the module config:
```toml
[memory_usage]
disabled = true
```

Or remove it from the format string (cleaner).

### Task 3: Change Module Icon/Symbol

```toml
[git_branch]
symbol = "󰘬 "  # Change to your preferred icon
```

Find icons at [Nerd Fonts Cheat Sheet](https://www.nerdfonts.com/cheat-sheet).

### Task 4: Adjust Module Content

Each module has different options. Example:

```toml
[directory]
truncation_length = 3      # Show only last 3 directories
truncate_to_repo = true    # Truncate to git repo root
format = "[ $path ]($style)"
```

Check [Starship documentation](https://starship.rs/config/) for module-specific options.

### Task 5: Change Background Color for One Module

1. Update palette (if needed):
   ```toml
   color_line_4 = '#ff0000'  # New red color
   ```

2. Update module style AND format:
   ```toml
   [directory]
   style = "fg:color_fg0 bg:color_line_4"
   format = "[ $path ](fg:color_fg0 bg:color_line_4)"
   ```

3. Update separators around it:
   ```toml
   [](fg:color_line_3 bg:color_line_4)\  # Before
   $directory\
   [](fg:color_line_4 bg:color_line_5)\  # After
   ```

### Task 6: Add a New Section with Different Color

1. Add color to palette:
   ```toml
   color_line_8 = '#123456'
   ```

2. Add separator + module to format:
   ```toml
   [](fg:color_line_7 bg:color_line_8)\
   $my_new_module\
   ```

3. Configure module:
   ```toml
   [my_new_module]
   style = "bg:color_line_8 fg:color_fg0"
   format = "[[ $symbol ](fg:color_fg0 bg:color_line_8)]($style)"
   ```

---

## Troubleshooting

### Problem: Background Colors Don't Match

**Symptom:** Black gaps or color breaks in the gradient.

**Solution:** Ensure `style` and `format` both specify the same background:
```toml
[git_branch]
style = "bg:color_line_1"  # ← Must match
format = '[[ $symbol $branch ](fg:color_fg0 bg:color_line_1)]($style)'  # ← Must match
```

### Problem: Custom Module Shows Variable Name

**Symptom:** Seeing `${custom.my_module}` or `.my_module` in prompt.

**Solution:** 
1. Use `${custom.name}` syntax (with curly braces) in format string
2. Ensure module is defined with `[custom.name]` section
3. Check that `when` condition returns true (test command manually)

### Problem: Colors Reset After Custom Module

**Symptom:** Everything after custom module loses background color.

**Solution:** Use `\033[39m` (reset foreground) instead of `\033[0m` (reset all) in your custom command:

```bash
# BAD - resets everything including background
printf "\\033[31mRed\\033[0m"

# GOOD - resets only foreground color
printf "\\033[31mRed\\033[39m"
```

### Problem: Gradient Looks Uneven

**Symptom:** Some color transitions are too abrupt, others too subtle.

**Solution:** Recalculate intermediate colors with better spacing. Use a color interpolation tool or manually adjust RGB values to create smoother transitions.

### Problem: Module Not Showing

**Checklist:**
1. Is it in the `format` string?
2. Is `disabled = false` (or not set)?
3. For custom modules: Does `when` condition pass?
4. For custom modules: Does `command` produce output?
5. Test command manually in terminal

---

## Quick Reference: Prompt for AI

When asking an AI to modify your Starship config, provide:

```
I want to modify my Starship prompt configuration at:
/Users/corey/Projects/dotfiles/apps/shared/starship/.config/starship.toml

Current setup:
- Using a gradient from [start color] to [end color]
- Modules in order: [list modules]
- Custom modules: [list custom modules and what they do]

Task: [specific change you want]

Important constraints:
1. Each module needs bg:color in BOTH style and format fields
2. Custom modules use ${custom.name} syntax in format string
3. Powerline separators use [](bg:new_color fg:old_color) before each section
4. ANSI codes in custom modules should use \033[39m not \033[0m to preserve background
5. Test all git-related features to ensure they work after commit

Please update the configuration following the CUSTOMIZATION_GUIDE.md in the same directory.
```

---

## Additional Resources

- [Starship Documentation](https://starship.rs/config/)
- [Nerd Fonts Cheat Sheet](https://www.nerdfonts.com/cheat-sheet) - For icons/symbols
- [UI Gradients](https://uigradients.com) - For gradient color inspiration
- [Coolors](https://coolors.co) - Color palette generator
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code) - For custom module colors

---

## Example: Complete Workflow for Changing Gradient

Let's say you want to change from "Deep Sea Space" to a purple gradient.

### Step 1: Find Gradient Colors
From uigradients.com: "Velvet Sun"
```css
linear-gradient(to right, #e1eec3, #f05053)
```

### Step 2: Calculate 10 Steps
```
#e1eec3 → #e5d9b8 → #e9c4ad → #edafa2 → #f19a97 → 
#f5858c → #f97081 → #fd5b76 → #ff466b → #f05053
```

### Step 3: Update Palette
```toml
[palettes.teal_gradient]
color_fg0 = '#ffffff'
color_fg1 = '#000000'
color_line_1 = '#e1eec3'
color_line_2 = '#e5d9b8'
color_line_3 = '#e9c4ad'
color_line_4 = '#edafa2'
color_line_5 = '#f19a97'
color_line_6 = '#f5858c'
color_line_7 = '#f97081'
color_right_1 = '#fd5b76'
color_right_2 = '#ff466b'
color_right_3 = '#f05053'
color_green = '#98971a'
color_red = '#cc241d'
color_purple = '#b16286'
```

### Step 4: No Module Changes Needed!
Since we're using color variables (`color_line_1`, etc.), modules automatically use the new colors. Just reload:
```bash
exec $SHELL
```

Done! Your gradient is now purple instead of blue.

---

## Conclusion

The key to successfully customizing Starship:
1. **Understand the three-part structure**: format, palette, modules
2. **Always sync colors**: `style` and `format` must match
3. **Test custom commands** before adding to config
4. **Use ANSI codes carefully** (reset foreground, not all formatting)
5. **Plan your gradient** before implementing

Happy customizing! 🚀
