#!/bin/bash

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/app-manager.sh"

# Default options
INSTALL_ALL=false
SKIP_DEPS=false
DRY_RUN=false
LIST_APPS=false
UNSTOW_MODE=false
RESTOW_MODE=false
APPS_TO_INSTALL=()

# Show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [APPS...]

Install dotfiles using GNU Stow with modular app management.

OPTIONS:
    -a, --all           Install all available apps for current OS
    -l, --list          List all available apps
    -n, --no-deps       Skip dependency installation (only stow configs)
    -d, --dry-run       Show what would be installed without doing it
    -u, --unstow        Unstow (remove) apps instead of installing
    -r, --restow        Restow (update) apps
    -h, --help          Show this help message

EXAMPLES:
    $(basename "$0") --all                    # Install everything
    $(basename "$0") git zsh starship         # Install specific apps
    $(basename "$0") --no-deps git            # Install git config only
    $(basename "$0") --list                   # List available apps
    $(basename "$0") --unstow git             # Remove git configuration
    $(basename "$0") --restow zsh             # Update zsh configuration

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                INSTALL_ALL=true
                shift
                ;;
            -l|--list)
                LIST_APPS=true
                shift
                ;;
            -n|--no-deps)
                SKIP_DEPS=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -u|--unstow)
                UNSTOW_MODE=true
                shift
                ;;
            -r|--restow)
                RESTOW_MODE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                APPS_TO_INSTALL+=("$1")
                shift
                ;;
        esac
    done
}

# List all available apps
list_apps() {
    local os=$(detect_os)
    
    echo ""
    log_info "Operating System: $os"
    echo ""
    
    # List shared apps
    if [[ -d "$APPS_DIR/shared" ]]; then
        echo -e "${CYAN}Shared Apps (cross-platform):${NC}"
        for app_dir in "$APPS_DIR/shared"/*; do
            if [[ -d "$app_dir" ]]; then
                local app_name=$(basename "$app_dir")
                local has_install=""
                if [[ -f "$app_dir/install-$os.sh" ]]; then
                    has_install=" ${GREEN}[has install]${NC}"
                fi
                echo -e "  - $app_name$has_install"
            fi
        done
        echo ""
    fi
    
    # List OS-specific apps
    if [[ -d "$APPS_DIR/$os" ]]; then
        echo -e "${MAGENTA}$os-specific Apps:${NC}"
        for app_dir in "$APPS_DIR/$os"/*; do
            if [[ -d "$app_dir" ]]; then
                local app_name=$(basename "$app_dir")
                local has_install=""
                if [[ -f "$app_dir/install.sh" ]]; then
                    has_install=" ${GREEN}[has install]${NC}"
                fi
                echo -e "  - $app_name$has_install"
            fi
        done
        echo ""
    fi
}

# Main installation logic
main() {
    parse_args "$@"
    
    # Show list and exit
    if [[ "$LIST_APPS" == "true" ]]; then
        list_apps
        exit 0
    fi
    
    # Detect OS
    local os=$(detect_os)
    if [[ "$os" == "unknown" ]]; then
        log_error "Unsupported operating system"
        exit 1
    fi
    
    log_info "Detected OS: $os"
    echo ""
    
    # Ensure stow is installed
    if ! ensure_stow; then
        exit 1
    fi
    echo ""
    
    # Determine which apps to process
    local apps=()
    if [[ "$INSTALL_ALL" == "true" ]]; then
        while IFS= read -r app; do
            apps+=("$app")
        done < <(list_available_apps)
    else
        apps=("${APPS_TO_INSTALL[@]}")
    fi
    
    # Check if any apps specified
    if [[ ${#apps[@]} -eq 0 ]]; then
        log_error "No apps specified. Use --all or specify app names."
        echo ""
        usage
        exit 1
    fi
    
    # Validate all apps exist before processing
    for app in "${apps[@]}"; do
        if ! app_exists "$app"; then
            log_error "App '$app' does not exist"
            log_info "Run '$(basename "$0") --list' to see available apps"
            exit 1
        fi
    done
    
    # Show what will be done
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - No changes will be made"
        echo ""
    fi
    
    if [[ "$UNSTOW_MODE" == "true" ]]; then
        log_info "Will unstow: ${apps[*]}"
    elif [[ "$RESTOW_MODE" == "true" ]]; then
        log_info "Will restow: ${apps[*]}"
    else
        log_info "Will install: ${apps[*]}"
        if [[ "$SKIP_DEPS" == "true" ]]; then
            log_warn "Skipping dependency installation"
        fi
    fi
    echo ""
    
    # Exit if dry run
    if [[ "$DRY_RUN" == "true" ]]; then
        exit 0
    fi
    
    # Process each app
    local success_count=0
    local fail_count=0
    
    for app in "${apps[@]}"; do
        if [[ "$UNSTOW_MODE" == "true" ]]; then
            if unstow_app "$app"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        elif [[ "$RESTOW_MODE" == "true" ]]; then
            if restow_app "$app"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        else
            if install_app "$app" "$SKIP_DEPS"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        fi
        echo ""
    done
    
    # Summary
    echo ""
    log_info "=========================================="
    if [[ "$UNSTOW_MODE" == "true" ]]; then
        log_success "Unstowed $success_count app(s)"
    elif [[ "$RESTOW_MODE" == "true" ]]; then
        log_success "Restowed $success_count app(s)"
    else
        log_success "Installed $success_count app(s)"
    fi
    
    if [[ $fail_count -gt 0 ]]; then
        log_error "Failed: $fail_count app(s)"
        exit 1
    fi
    
    echo ""
    log_success "All done!"
}

main "$@"
