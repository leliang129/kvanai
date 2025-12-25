#!/bin/bash
# Codex CLI Installation Script (macOS)
# Usage: ./install-codex-macos.sh [BASE_URL] [API_KEY]
# Example: ./install-codex-macos.sh "https://codex.heihuzicity.com/openai" "cr_xxxxxxxxxx"

set -e

# Parameter parsing
BASE_URL="${1:-https://codex.heihuzicity.com/openai}"
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
echo "   Codex CLI Installation (macOS)"
echo "========================================${NC}"
echo ""

# Detect shell type
SHELL_TYPE="zsh"
SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == *"bash"* ]]; then
    SHELL_TYPE="bash"
    SHELL_RC="$HOME/.bash_profile"
fi
info "Detected shell: $SHELL_TYPE"

# 1. Check Node.js
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
    # Prefer Homebrew
    if command -v brew &> /dev/null; then
        info "Installing Node.js via Homebrew..."
        brew install node || brew upgrade node
        success "Node.js installed: $(node --version)"
    else
        # No Homebrew, use binary install
        info "Homebrew not detected, using binary install for Node.js..."
        NODE_VERSION="20.18.0"
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            ARCH="x64"
        elif [[ "$ARCH" == "arm64" ]]; then
            ARCH="arm64"
        fi
        
        NODE_DIST="node-v${NODE_VERSION}-darwin-${ARCH}"
        NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_DIST}.tar.gz"
        
        cd /tmp
        info "Downloading Node.js v${NODE_VERSION}..."
        curl -fsSL "$NODE_URL" -o "${NODE_DIST}.tar.gz"
        
        info "Extracting and installing to /usr/local..."
        sudo tar -xzf "${NODE_DIST}.tar.gz" -C /usr/local --strip-components=1
        rm -f "${NODE_DIST}.tar.gz"
        cd - > /dev/null
        
        success "Node.js binary install complete: $(node --version)"
    fi
fi

# 3. Check npm
info "Checking npm..."
if command -v npm &> /dev/null; then
    success "npm installed: v$(npm --version)"
else
    error "npm not found, please reinstall Node.js"
    exit 1
fi

# 4. Install Codex CLI
info "Installing Codex CLI..."
if command -v codex &> /dev/null; then
    CODEX_VERSION=$(codex --version 2>/dev/null || echo "unknown")
    success "Codex CLI already installed: $CODEX_VERSION"
    info "Updating to latest version..."
fi

npm install -g @openai/codex 2>/dev/null || sudo npm install -g @openai/codex

if command -v codex &> /dev/null; then
    CODEX_VERSION=$(codex --version 2>/dev/null || echo "installed")
    success "Codex CLI installed: $CODEX_VERSION"
else
    error "Codex CLI installation failed"
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
    
    # Check if already exists
    if grep -q "CRS_OAI_KEY" "$SHELL_RC" 2>/dev/null; then
        # Update existing config
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/export CRS_OAI_KEY=.*/export CRS_OAI_KEY=\"$API_KEY\"/" "$SHELL_RC"
        else
            sed -i "s/export CRS_OAI_KEY=.*/export CRS_OAI_KEY=\"$API_KEY\"/" "$SHELL_RC"
        fi
        success "Environment variable updated"
    else
        # Add new config
        echo "" >> "$SHELL_RC"
        echo "# Codex CLI Configuration" >> "$SHELL_RC"
        echo "export CRS_OAI_KEY=\"$API_KEY\"" >> "$SHELL_RC"
        success "Environment variable added to $SHELL_RC"
    fi
    
    # Apply immediately
    export CRS_OAI_KEY="$API_KEY"
else
    warn "No API Key provided, skipping environment variable configuration"
    info "You can manually add to $SHELL_RC later:"
    echo "  export CRS_OAI_KEY=\"your_api_key\""
fi

# 7. Create configuration files
info "Creating configuration files..."
CODEX_DIR="$HOME/.codex"
mkdir -p "$CODEX_DIR"

# config.toml
CONFIG_PATH="$CODEX_DIR/config.toml"
if [[ -f "$CONFIG_PATH" ]]; then
    BACKUP="$CONFIG_PATH.backup.$(date +%Y%m%d%H%M%S)"
    cp "$CONFIG_PATH" "$BACKUP"
    info "Backed up original config to: $BACKUP"
fi

cat > "$CONFIG_PATH" << EOF
model_provider = "crs"
model = "gpt-5-codex"
model_reasoning_effort = "high"
disable_response_storage = true
preferred_auth_method = "apikey"

[model_providers.crs]
name = "crs"
base_url = "$BASE_URL"
wire_api = "responses"
requires_openai_auth = true
env_key = "CRS_OAI_KEY"
EOF
success "Config file created: $CONFIG_PATH"

# auth.json
AUTH_PATH="$CODEX_DIR/auth.json"
cat > "$AUTH_PATH" << 'EOF'
{
  "OPENAI_API_KEY": null
}
EOF
success "Auth file created: $AUTH_PATH"

# 8. Done
echo ""
echo -e "${GREEN}========================================"
echo "   Installation Complete!"
echo "========================================${NC}"
echo ""
info "Config location: $CODEX_DIR"
info "Environment config: $SHELL_RC"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo "  1. Reload config: source $SHELL_RC"
echo "  2. Navigate to project: cd your-project"
echo "  3. Start Codex: codex"
echo ""

info "Run 'source $SHELL_RC' to apply configuration, then type 'codex' to start"
