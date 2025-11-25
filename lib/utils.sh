#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${MAGENTA}[STEP]${NC} $1"
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if running on macOS
is_macos() {
    [[ "$(detect_os)" == "macos" ]]
}

# Check if running on Linux
is_linux() {
    [[ "$(detect_os)" == "linux" ]]
}

# Detect Linux distribution
detect_linux_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Check if Homebrew is installed
has_homebrew() {
    command_exists brew
}

# Check if apt is available
has_apt() {
    command_exists apt
}

# Check if yum is available
has_yum() {
    command_exists yum
}

# Check if stow is installed
has_stow() {
    command_exists stow
}

# Install stow if not present
ensure_stow() {
    if has_stow; then
        log_info "GNU Stow is already installed"
        return 0
    fi

    log_step "Installing GNU Stow..."
    
    if is_macos; then
        if ! has_homebrew; then
            log_error "Homebrew is required but not installed. Please install Homebrew first."
            return 1
        fi
        brew install stow
    elif is_linux; then
        if has_apt; then
            sudo apt install -y stow
        elif has_yum; then
            sudo yum install -y stow
        else
            log_error "Unable to install stow. Please install it manually."
            return 1
        fi
    fi

    if has_stow; then
        log_success "GNU Stow installed successfully"
        return 0
    else
        log_error "Failed to install GNU Stow"
        return 1
    fi
}

# Confirm action with user
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    read -p "$prompt" -n 1 -r
    echo
    
    if [[ "$default" == "y" ]]; then
        [[ $REPLY =~ ^[Yy]?$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Get script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
