#!/bin/bash

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

APPS_DIR="$SCRIPT_DIR/apps"
OS=$(detect_os)

# Get list of all available apps for current OS
list_available_apps() {
    local apps=()
    
    # Add shared apps
    if [[ -d "$APPS_DIR/shared" ]]; then
        for app_dir in "$APPS_DIR/shared"/*; do
            if [[ -d "$app_dir" ]]; then
                apps+=("$(basename "$app_dir")")
            fi
        done
    fi
    
    # Add OS-specific apps
    if [[ -d "$APPS_DIR/$OS" ]]; then
        for app_dir in "$APPS_DIR/$OS"/*; do
            if [[ -d "$app_dir" ]]; then
                local app_name=$(basename "$app_dir")
                # Only add if not already in list (shared takes precedence)
                if [[ ! " ${apps[@]} " =~ " ${app_name} " ]]; then
                    apps+=("$app_name")
                fi
            fi
        done
    fi
    
    printf '%s\n' "${apps[@]}" | sort
}

# Check if app exists
app_exists() {
    local app_name="$1"
    
    [[ -d "$APPS_DIR/shared/$app_name" ]] || [[ -d "$APPS_DIR/$OS/$app_name" ]]
}

# Get app directory path
get_app_dir() {
    local app_name="$1"
    
    # Check shared first
    if [[ -d "$APPS_DIR/shared/$app_name" ]]; then
        echo "$APPS_DIR/shared/$app_name"
    elif [[ -d "$APPS_DIR/$OS/$app_name" ]]; then
        echo "$APPS_DIR/$OS/$app_name"
    else
        echo ""
    fi
}

# Get app type (shared or os-specific)
get_app_type() {
    local app_name="$1"
    
    if [[ -d "$APPS_DIR/shared/$app_name" ]]; then
        echo "shared"
    elif [[ -d "$APPS_DIR/$OS/$app_name" ]]; then
        echo "$OS"
    else
        echo "unknown"
    fi
}

# Run app installation script
install_app_dependencies() {
    local app_name="$1"
    local app_dir=$(get_app_dir "$app_name")
    local app_type=$(get_app_type "$app_name")
    
    if [[ -z "$app_dir" ]]; then
        log_error "App '$app_name' not found"
        return 1
    fi
    
    local install_script=""
    
    # Determine which install script to run
    if [[ "$app_type" == "shared" ]]; then
        # Look for OS-specific install script
        install_script="$app_dir/install-$OS.sh"
    else
        # Look for generic install script
        install_script="$app_dir/install.sh"
    fi
    
    # Check if install script exists
    if [[ ! -f "$install_script" ]]; then
        log_info "No installation script for '$app_name' (skipping dependency installation)"
        return 0
    fi
    
    # Make sure script is executable
    chmod +x "$install_script"
    
    log_step "Installing dependencies for '$app_name'..."
    
    # Run the install script
    if (cd "$app_dir" && bash "$install_script"); then
        log_success "Dependencies for '$app_name' installed successfully"
        return 0
    else
        log_error "Failed to install dependencies for '$app_name'"
        return 1
    fi
}

# Check if app is already stowed
is_app_stowed() {
    local app_name="$1"
    local app_dir=$(get_app_dir "$app_name")
    
    if [[ -z "$app_dir" ]]; then
        return 1
    fi
    
    # Check if any file from the app is already symlinked correctly
    local found_symlink=false
    local has_config_files=false
    
    # Find files in app directory (excluding install scripts)
    while IFS= read -r file; do
        # Get relative path from app directory
        local rel_path="${file#$app_dir/}"
        
        # Skip if it's an install script
        if [[ "$rel_path" =~ ^install.*\.sh$ ]]; then
            continue
        fi
        
        has_config_files=true
        
        # Check if symlink exists in home and points to correct location
        local target_path="$HOME/$rel_path"
        if [[ -L "$target_path" ]]; then
            local link_target=$(readlink "$target_path")
            # Check if it points to the current app location
            if [[ "$link_target" == *"apps/shared/$app_name/"* ]] || [[ "$link_target" == *"apps/$OS/$app_name/"* ]]; then
                found_symlink=true
                break
            fi
        fi
    done < <(find "$app_dir" -type f 2>/dev/null)
    
    # If no config files exist (only install script), consider it "not stowed"
    # This allows apps like brave/slack to be checked via other means
    if [[ "$has_config_files" == "false" ]]; then
        return 1
    fi
    
    if [[ "$found_symlink" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Clean up old/broken symlinks for an app
cleanup_old_symlinks() {
    local app_name="$1"
    
    # Find and remove broken symlinks that point to old dotfiles structure
    find "$HOME" -maxdepth 3 -type l 2>/dev/null | while read -r link; do
        local target=$(readlink "$link" 2>/dev/null || echo "")
        # Check if it points to old dotfiles structure (without /apps/)
        if [[ "$target" == *"dotfiles/$app_name/"* ]] || [[ "$target" == *"Projects/dotfiles/$app_name/"* ]]; then
            log_info "Removing old symlink: $link"
            rm -f "$link"
        fi
    done
}

# Stow app configuration
stow_app() {
    local app_name="$1"
    local app_dir=$(get_app_dir "$app_name")
    
    if [[ -z "$app_dir" ]]; then
        log_error "App '$app_name' not found"
        return 1
    fi
    
    local app_type=$(get_app_type "$app_name")
    local stow_dir=""
    
    if [[ "$app_type" == "shared" ]]; then
        stow_dir="$APPS_DIR/shared"
    else
        stow_dir="$APPS_DIR/$OS"
    fi
    
    # Clean up old symlinks first
    cleanup_old_symlinks "$app_name"
    
    log_step "Stowing '$app_name' configuration..."
    
    # Run stow from the appropriate directory with explicit target
    if (cd "$stow_dir" && stow -v --dotfiles --target="$HOME" --adopt --ignore='^install\.sh$' --ignore='^install-.*\.sh$' "$app_name" 2>&1); then
        log_success "Configuration for '$app_name' stowed successfully"
        return 0
    else
        log_error "Failed to stow configuration for '$app_name'"
        return 1
    fi
}

# Unstow app configuration
unstow_app() {
    local app_name="$1"
    local app_type=$(get_app_type "$app_name")
    
    if [[ "$app_type" == "unknown" ]]; then
        log_error "App '$app_name' not found"
        return 1
    fi
    
    local stow_dir=""
    
    if [[ "$app_type" == "shared" ]]; then
        stow_dir="$APPS_DIR/shared"
    else
        stow_dir="$APPS_DIR/$OS"
    fi
    
    log_step "Unstowing '$app_name' configuration..."
    
    # Run stow -D from the appropriate directory with explicit target
    if (cd "$stow_dir" && stow -D -v --dotfiles --target="$HOME" "$app_name" 2>&1); then
        log_success "Configuration for '$app_name' unstowed successfully"
        return 0
    else
        log_error "Failed to unstow configuration for '$app_name'"
        return 1
    fi
}

# Restow app configuration
restow_app() {
    local app_name="$1"
    local app_type=$(get_app_type "$app_name")
    
    if [[ "$app_type" == "unknown" ]]; then
        log_error "App '$app_name' not found"
        return 1
    fi
    
    local stow_dir=""
    
    if [[ "$app_type" == "shared" ]]; then
        stow_dir="$APPS_DIR/shared"
    else
        stow_dir="$APPS_DIR/$OS"
    fi
    
    log_step "Restowing '$app_name' configuration..."
    
    # Run stow -R from the appropriate directory with explicit target
    if (cd "$stow_dir" && stow -R -v --dotfiles --target="$HOME" --adopt --ignore='^install\.sh$' --ignore='^install-.*\.sh$' "$app_name" 2>&1); then
        log_success "Configuration for '$app_name' restowed successfully"
        return 0
    else
        log_error "Failed to restow configuration for '$app_name'"
        return 1
    fi
}

# Install app (dependencies + stow)
install_app() {
    local app_name="$1"
    local skip_deps="${2:-false}"
    
    if ! app_exists "$app_name"; then
        log_error "App '$app_name' does not exist"
        return 1
    fi
    
    log_info "Installing '$app_name'..."
    
    # Check if already stowed - if so, skip dependencies
    if is_app_stowed "$app_name"; then
        log_info "App '$app_name' is already stowed (skipping dependencies)"
        skip_deps=true
    fi
    
    # Install dependencies unless skipped
    if [[ "$skip_deps" == "false" ]]; then
        install_app_dependencies "$app_name" || return 1
    fi
    
    # Stow configuration
    stow_app "$app_name" || return 1
    
    log_success "App '$app_name' installed successfully"
    return 0
}
