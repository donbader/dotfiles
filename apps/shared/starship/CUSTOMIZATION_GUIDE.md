# Starship Prompt Customization Guide

Quick guide for customizing your Starship prompt gradient and layout.

## Quick Start: Change Gradient Colors

### 1. Find a Gradient
Visit [uigradients.com](https://uigradients.com) and copy the CSS gradient colors.

Example:
```css
background: linear-gradient(to right, #2c3e50, #4ca1af);
```

### 2. Calculate 15 Color Steps

Use this Python script to generate the gradient:

```python
python3 << 'EOF'
# Start and end colors from your gradient
r_start, g_start, b_start = 0x2c, 0x3e, 0x50  # #2c3e50
r_end, g_end, b_end = 0x4c, 0xa1, 0xaf        # #4ca1af

# Generate 15 steps
steps = 15
for i in range(steps):
    r = int(r_start + (r_end - r_start) * (i / (steps - 1)))
    g = int(g_start + (g_end - g_start) * (i / (steps - 1)))
    b = int(b_start + (b_end - b_start) * (i / (steps - 1)))
    print(f"color_line_{i+1} = '#{r:02x}{g:02x}{b:02x}'  # Step {i+1}/15")
EOF
```

### 3. Update the Palette

Edit `~/.config/starship.toml` and replace the `[palettes.teal_gradient]` section with your new colors:

```toml
[palettes.teal_gradient]
color_fg0 = '#ffffff'
color_fg1 = '#000000'
color_line_1 = '#2c3e50'   # Paste generated colors here
color_line_2 = '#2e4556'
# ... paste all 15 colors
color_line_15 = '#4ca1af'
# Status colors (keep these)
color_green = '#98971a'
color_red = '#cc241d'
color_purple = '#b16286'
```

### 4. Reload
```bash
exec $SHELL
```

Done! Your gradient updates automatically.

---

## Add More Gradient Spaces

To make the gradient more visible with wider color blocks, add empty spaces in the format string:

```toml
format = """
[](color_line_1)\
$directory\
[](bg:color_line_2 fg:color_line_1)\
[ ](bg:color_line_2)\  # ← Add these empty space blocks
[](bg:color_line_3 fg:color_line_2)\
[ ](bg:color_line_3)\  # ← wherever you want wider sections
...
"""
```

Each `[ ](bg:color_line_X)` creates a visible colored block showing that gradient step.

---

## Important Rules

### 1. Fill Module Must Match Position
The `$fill` module expands to fill terminal width. Its background color should match its position in the gradient:

```toml
# If $fill appears after color_line_7, use color_line_8
[fill]
symbol = " "
style = "bg:color_line_8"
```

### 2. Module Background Colors Must Match
Each module needs the same background in TWO places:

```toml
[directory]
style = "bg:color_line_1"  # ← Must match
format = "[ $path ](fg:color_fg0 bg:color_line_1)"  # ← Must match
```

### 3. Powerline Separators
Separators transition between colors:
```toml
[](bg:color_line_2 fg:color_line_1)  # Transitions from line_1 to line_2
```

---

## Current Layout (15-step gradient)

The prompt uses these color assignments:
- `color_line_1` → directory
- `color_line_2` → jobs
- `color_line_3-7` → empty gradient spaces
- `color_line_8` → fill (center expander)
- `color_line_9-11` → empty gradient spaces
- `color_line_12` → docker/kubernetes/aws (cloud services)
- `color_line_13` → os icon
- `color_line_14` → username
- `color_line_15` → time

---

## Troubleshooting

**Gradient looks broken/has dark gaps:**
- Check that `$fill` background color matches its position
- Ensure module `style` and `format` fields use the same `bg:color_line_X`

**Module not showing:**
- Check `disabled = false` in module config
- For custom modules, test the `command` manually first

**Colors jump backwards:**
- Verify the format string uses ascending color numbers (1→2→3, not 1→5→2)

---

## Resources

- [Starship Docs](https://starship.rs/config/) - Full module options
- [UI Gradients](https://uigradients.com) - Gradient inspiration
- [Nerd Fonts](https://www.nerdfonts.com/cheat-sheet) - Icons for modules
