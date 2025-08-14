#!/bin/bash
# install.sh - Install piphub from GitHub releases (Linux)

set -euo pipefail

REPO="ltanedo/clify-py"
INSTALL_DIR="/usr/local/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if running as root for system install
if [[ $EUID -eq 0 ]]; then
    INSTALL_DIR="/usr/local/bin"
    info "Installing system-wide to $INSTALL_DIR"
else
    INSTALL_DIR="$HOME/.local/bin"
    info "Installing to user directory $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Get latest release info
info "Fetching latest release information..."
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
TAG_NAME=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
VERSION=${TAG_NAME#v}

if [[ -z "$TAG_NAME" ]]; then
    error "Failed to get latest release information"
    exit 1
fi

info "Latest version: $TAG_NAME"

# Check if we have a .deb package available
DEB_URL="https://github.com/$REPO/releases/download/$TAG_NAME/piphub_${VERSION}_all.deb"

# Try to install via .deb if available and we're on Debian/Ubuntu
if command -v dpkg >/dev/null 2>&1 && [[ $EUID -eq 0 ]]; then
    info "Attempting to install .deb package..."
    TEMP_DEB=$(mktemp)
    
    if curl -sL "$DEB_URL" -o "$TEMP_DEB" && file "$TEMP_DEB" | grep -q "Debian binary package"; then
        info "Installing .deb package..."
        dpkg -i "$TEMP_DEB" || {
            warn ".deb installation failed, trying to fix dependencies..."
            apt-get install -f -y
        }
        rm -f "$TEMP_DEB"
        info "Installation complete! You can now use: piphub, piphub-bash"
        exit 0
    else
        warn ".deb package not available, falling back to direct script installation"
        rm -f "$TEMP_DEB"
    fi
fi

# Fallback: Download scripts directly
info "Installing scripts directly..."

# Download bash script
BASH_URL="https://raw.githubusercontent.com/$REPO/$TAG_NAME/piphub.bash"
curl -sL "$BASH_URL" -o "$INSTALL_DIR/piphub-bash"
chmod +x "$INSTALL_DIR/piphub-bash"

# Download PowerShell script
PS_URL="https://raw.githubusercontent.com/$REPO/$TAG_NAME/piphub.ps1"
curl -sL "$PS_URL" -o "$INSTALL_DIR/piphub-ps.ps1"
chmod +x "$INSTALL_DIR/piphub-ps.ps1"

# Create symlink for default command
ln -sf "$INSTALL_DIR/piphub-bash" "$INSTALL_DIR/piphub"

info "Installation complete!"
info "Commands available:"
info "  piphub       - Default (bash version)"
info "  piphub-bash  - Bash version"
info "  piphub-ps.ps1 - PowerShell version"

# Check if install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    warn "$INSTALL_DIR is not in your PATH"
    warn "Add this to your ~/.bashrc or ~/.zshrc:"
    warn "export PATH=\"$INSTALL_DIR:\$PATH\""
fi
