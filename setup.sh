#!/usr/bin/env bash
# ==============================================================================
# One-Click Setup & Launcher for GitHub Runner Environment
# ==============================================================================
set -euo pipefail

echo "=========================================="
echo "🚀 Starting Automated Environment Setup"
echo "=========================================="

# 1. System Package Requirements & tmux
echo "📦 [1/7] Checking system packages & tmux..."
# Note: We skip 'apt upgrade' to save 3-5 minutes on runner startup
if ! command -v curl &> /dev/null || ! command -v wget &> /dev/null || ! command -v make &> /dev/null || ! command -v tmux &> /dev/null; then
  echo "Installing system build essentials and tmux..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq curl git wget build-essential tmux
else
  echo "✅ Essential build packages & tmux already present."
fi

# Configure tmux (enable mouse scrolling & pane selection)
if [ ! -f "$HOME/.tmux.conf" ] || ! grep -q "mouse on" "$HOME/.tmux.conf" 2>/dev/null; then
  echo "set -g mouse on" >> "$HOME/.tmux.conf"
  echo "✅ Configured tmux mouse scrolling in ~/.tmux.conf."
fi

# 2. Python Environment & Virtual Environments
echo "🐍 [2/7] Checking Python, pip, and venv..."
if ! command -v pip3 &> /dev/null || ! python3 -m venv -h &> /dev/null; then
  echo "Installing Python pip and venv..."
  sudo apt-get update -qq
  sudo apt-get install -qq -y python3-pip python3-venv
else
  echo "✅ Python ($(python3 --version | cut -d' ' -f2)), pip, and venv are already installed."
fi

# 3. Node.js Environment
echo "🟢 [3/7] Checking Node.js..."
if ! command -v node &> /dev/null; then
  echo "Node.js not found. Installing Node.js LTS..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y -qq nodejs
else
  echo "✅ Node.js is already installed ($(node -v)). Skipping install."
fi

# 4. Playwright & Browser Dependencies (Node.js)
echo "🌐 [4/7] Installing Playwright Chromium & system browser dependencies..."
npx playwright install --with-deps chromium

# 5. PATH Configuration
echo "⚙️ [5/7] Configuring PATH..."
export PATH="$HOME/.local/bin:$HOME/.gemini/antigravity-cli/bin:$PATH"

# Make PATH changes permanent across subshells in this runner
if ! grep -q ".local/bin" "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$HOME/.gemini/antigravity-cli/bin:$PATH"' >> "$HOME/.bashrc"
fi

# 6. GitHub CLI & Git Credentials
echo "🐙 [6/7] Checking GitHub & Git configuration..."
# Ensure default git commit identity is set
if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
  git config --global user.name "Antigravity Agent"
  git config --global user.email "agent@users.noreply.github.com"
fi

# Step A: Check if GH_TOKEN is already present in environment
if [ -n "${GH_TOKEN:-}" ]; then
  echo "Found GH_TOKEN in environment. Authenticating GitHub CLI automatically..."
  token_val="$GH_TOKEN"
  unset GH_TOKEN GITHUB_TOKEN
  echo "$token_val" | gh auth login --with-token
  gh auth setup-git
  echo "✅ GitHub CLI authenticated successfully via environment token."

# Step B: Check if already authenticated from a previous session
elif gh auth status &> /dev/null; then
  echo "✅ GitHub CLI is already authenticated as $(gh api user -q .login 2>/dev/null || echo 'user')."
  gh auth setup-git

# Step C: Prompt with choices if not logged in
else
  echo ""
  echo "⚠️  GitHub is not logged in."
  echo "How would you like to log in?"
  echo "  1) Web Browser / Device Code (open link on phone or laptop)"
  echo "  2) Paste GitHub Personal Access Token (PAT)"
  echo "  3) Skip for now (login later manually)"
  echo ""
  read -r -p "Select an option [1-3]: " gh_choice

  case "$gh_choice" in
    1)
      echo ""
      echo "🌐 Starting GitHub Device Login..."
      echo "👉 Copy the code displayed below, then visit https://github.com/login/device"
      echo ""
      gh auth login --hostname github.com --git-protocol https --web
      gh auth setup-git
      echo "✅ GitHub authentication complete and Git credentials configured!"
      ;;
    2)
      echo ""
      read -r -s -p "🔑 Paste your GitHub Token (input will be hidden): " user_gh_token
      echo ""
      if [ -n "$user_gh_token" ]; then
        echo "$user_gh_token" | gh auth login --with-token
        gh auth setup-git
        echo "✅ Authenticated successfully with token!"
      else
        echo "⚠️ No token provided. Skipping GitHub login."
      fi
      ;;
    *)
      echo "⏩ Skipping GitHub login for now."
      ;;
  esac
fi

# 7. Antigravity CLI (agy) Installation
echo "📦 [7/7] Checking Antigravity CLI..."
if command -v agy &> /dev/null; then
  echo "✅ Antigravity CLI (agy) is already installed."
else
  echo "📥 Installing Antigravity CLI..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash
fi

# Summary & Instructions
echo ""
echo "============================================================"
echo "🎉 ALL DONE! Your environment is completely ready."
echo "============================================================"
echo "  ✔ System packages (curl, git, wget, build-essential)"
echo "  ✔ tmux ($(tmux -V)) with mouse scrolling enabled"
echo "  ✔ Python ($(python3 --version | cut -d' ' -f2)), pip & venv"
echo "  ✔ Node.js ($(node -v)) & npm ($(npm -v))"
echo "  ✔ Playwright Chromium & browser dependencies"
echo "  ✔ Git identity & GitHub CLI (gh)"
echo "  ✔ PATH configured ($HOME/.local/bin)"
echo "  ✔ Antigravity CLI (agy) installed"
echo "============================================================"
echo "👉 Next steps:"
echo "   1. GitHub Login (if not logged in):"
echo "      gh auth login && gh auth setup-git"
echo ""
echo "   2. Launch Antigravity (tip: run inside tmux to persist your session):"
echo "      agy"
echo "      (or: tmux new -s agent 'agy')"
echo "============================================================"
