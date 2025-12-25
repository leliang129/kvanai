#!/bin/bash
# Claude Code Installation Script (Linux / WSL2)
# Usage: ./install-claude-linux.sh [BASE_URL] [API_KEY]
# Example: ./install-claude-linux.sh "https://codex.heihuzicity.com/claude" "cr_xxxxxxxxxx"

set -e

# Parameter parsing
BASE_URL="${1:-https://codex.heihuzicity.com/claude}"
API_KEY="${2:-}"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo -e "${MAGENTA}========================================"
echo "   Claude Code Installation (Linux)"
echo "========================================${NC}"
echo ""

# Detect distribution
DISTRO="unknown"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO="$ID"
fi
info "Detected system: $DISTRO"

# Detect shell type
SHELL_TYPE="bash"
SHELL_RC="$HOME/.bashrc"
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_TYPE="zsh"
    SHELL_RC="$HOME/.zshrc"
fi
info "Detected shell: $SHELL_TYPE"

# Detect package manager
PKG_MANAGER=""
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
fi
info "Detected package manager: $PKG_MANAGER"

# 1. Check and install curl
info "Checking curl..."
if ! command -v curl &> /dev/null; then
    warn "curl not installed, installing..."
    case $PKG_MANAGER in
        apt) sudo apt-get update && sudo apt-get install -y curl ;;
        dnf) sudo dnf install -y curl ;;
        yum) sudo yum install -y curl ;;
        pacman) sudo pacman -S --noconfirm curl ;;
        *) error "Cannot auto-install curl, please install manually"; exit 1 ;;
    esac
fi
success "curl ready"

# 2. Check Node.js
info "Checking Node.js..."
NEED_NODE_INSTALL=false

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    VERSION_NUM=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
    
    if [[ "$VERSION_NUM" -ge 18 ]]; then
        success "Node.js installed: $NODE_VERSION"
    else
        warn "Node.js version too low ($NODE_VERSION), requires v18.x or higher"
        NEED_NODE_INSTALL=true
    fi
else
    warn "Node.js not detected"
    NEED_NODE_INSTALL=true
fi

if [[ "$NEED_NODE_INSTALL" == true ]]; then
    info "Installing Node.js LTS..."
    
    case $PKG_MANAGER in
        apt)
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        dnf)
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
            sudo dnf install -y nodejs
            ;;
        yum)
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        pacman)
            sudo pacman -S --noconfirm nodejs npm
            ;;
        *)
            error "Cannot auto-install Node.js, please install manually"
            info "Visit https://nodejs.org/ to download"
            exit 1
            ;;
    esac
    
    if command -v node &> /dev/null; then
        success "Node.js installed: $(node --version)"
    else
        error "Node.js installation failed"
        exit 1
    fi
fi

# 3. Check npm
info "Checking npm..."
if command -v npm &> /dev/null; then
    success "npm installed: v$(npm --version)"
else
    error "npm not found"
    case $PKG_MANAGER in
        apt) sudo apt-get install -y npm ;;
        dnf) sudo dnf install -y npm ;;
        yum) sudo yum install -y npm ;;
        *) error "Please install npm manually"; exit 1 ;;
    esac
fi

# 4. Install Claude Code CLI
info "Installing Claude Code CLI..."
if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
    success "Claude Code CLI already installed: $CLAUDE_VERSION"
    info "Updating to latest version..."
fi

# Try install without sudo
npm install -g @anthropic-ai/claude-code 2>/dev/null || {
    warn "Need sudo for global package install..."
    sudo npm install -g @anthropic-ai/claude-code
}

if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "installed")
    success "Claude Code CLI installed: $CLAUDE_VERSION"
else
    error "Claude Code CLI installation failed"
    exit 1
fi

# 5. Get parameters
echo ""
info "Current configuration:"
echo "  Base URL: $BASE_URL"

if [[ -z "$API_KEY" ]]; then
    warn "No API Key provided. Pass it as second argument"
fi

# 6. Set environment variables
if [[ -n "$API_KEY" ]]; then
    info "Configuring environment variables..."
    
    # Ensure config file exists
    touch "$SHELL_RC"
    
    # Check if already exists
    if grep -q "ANTHROPIC_BASE_URL" "$SHELL_RC" 2>/dev/null; then
        # Update existing config
        sed -i "s|export ANTHROPIC_BASE_URL=.*|export ANTHROPIC_BASE_URL=\"$BASE_URL\"|" "$SHELL_RC"
        sed -i "s/export ANTHROPIC_API_KEY=.*/export ANTHROPIC_API_KEY=\"$API_KEY\"/" "$SHELL_RC"
        success "Environment variables updated"
    else
        # Add new config
        echo "" >> "$SHELL_RC"
        echo "# Claude Code Configuration" >> "$SHELL_RC"
        echo "export ANTHROPIC_BASE_URL=\"$BASE_URL\"" >> "$SHELL_RC"
        echo "export ANTHROPIC_API_KEY=\"$API_KEY\"" >> "$SHELL_RC"
        success "Environment variables added to $SHELL_RC"
    fi
    
    # Apply immediately
    export ANTHROPIC_BASE_URL="$BASE_URL"
    export ANTHROPIC_API_KEY="$API_KEY"
else
    warn "No API Key provided, skipping environment variable configuration"
    info "You can manually add to $SHELL_RC later:"
    echo "  export ANTHROPIC_BASE_URL=\"$BASE_URL\""
    echo "  export ANTHROPIC_API_KEY=\"your_api_key\""
fi

# 7. Done
echo ""
echo -e "${GREEN}========================================"
echo "   Installation Complete!"
echo "========================================${NC}"
echo ""
info "Environment config: $SHELL_RC"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo "  1. Reload config: source $SHELL_RC"
echo "  2. Navigate to project: cd your-project"
echo "  3. Start Claude Code: claude"
echo ""

info "Run 'source $SHELL_RC' to apply configuration, then type 'claude' to start"
