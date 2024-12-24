#!/bin/bash

# Detect the shell configuration file
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bashrc"
else
    echo "Unsupported shell. Please manually add ~/.local/bin to your PATH"
    SHELL_RC=""
fi

# Create local bin directory if it doesn't exist
echo "Creating local bin directory..."
mkdir -p ~/.local/bin

# Add to PATH if not already there

echo "Adding ~/.local/bin to PATH in $SHELL_RC..."
echo 'export PATH=$PATH:$HOME/.local/bin' >> "$SHELL_RC"
export PATH=$PATH:$HOME/.local/bin


# Download latest gh release
echo "Downloading GitHub CLI..."
VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep -o 'tag/v[0-9.]*' | cut -d'/' -f2)
VERSION_NO_V="${VERSION#v}"
curl -Lo gh.tar.gz "https://github.com/cli/cli/releases/latest/download/gh_${VERSION_NO_V}_linux_amd64.tar.gz"

# Extract and install
echo "Installing GitHub CLI..."
tar xvf gh.tar.gz
mv gh_*/bin/gh ~/.local/bin/
rm -rf gh_* gh.tar.gz
# Re-read shell configuration to update PATH
if [ -n "$SHELL_RC" ]; then
    echo "Reloading shell configuration from $SHELL_RC..."
    if [ -n "$ZSH_VERSION" ]; then
        source "$SHELL_RC"
    elif [ -n "$BASH_VERSION" ]; then
        source "$SHELL_RC"
    fi
fi

# Verify installation
if command -v gh &> /dev/null; then
    echo "GitHub CLI installed successfully!"
    echo "Version: $(gh --version)"
    echo "Please run 'gh auth login' to authenticate"
else
    echo "Installation failed. Please check if ~/.local/bin is in your PATH"
    echo "Current PATH: $PATH"
fi 