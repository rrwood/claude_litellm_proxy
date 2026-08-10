#!/bin/bash
set -e

# Get the actual username from build args (defaults to litellm)
USERNAME=${USERNAME:-litellm}
USER_PASSWORD=${USER_PASSWORD:-changeme123}
USER_HOME="/home/${USERNAME}"

# Set user password (allows runtime password changes via env var)
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd

# Start SSH service
/usr/sbin/sshd

# Check if .env file exists, if not create from example
if [ ! -f "$USER_HOME/.config/litellm/.env" ]; then
    cp "$USER_HOME/.config/litellm/.env.example" "$USER_HOME/.config/litellm/.env"
    chown ${USERNAME}:${USERNAME} "$USER_HOME/.config/litellm/.env"
    echo "================================================"
    echo "IMPORTANT: Configure your NVIDIA NIM API key"
    echo "================================================"
    echo "Edit: ~/.config/litellm/.env"
    echo "Get API key: https://build.nvidia.com/nim"
    echo ""
fi

# Pull config from a git repo if CONFIG_REPO_URL is set
CONFIG_DIR="$USER_HOME/.config/litellm"
CONFIG_REPO_DIR="$USER_HOME/.config/litellm/config-repo"
CONFIG_REPO_BRANCH="${CONFIG_REPO_BRANCH:-main}"
CONFIG_REPO_PATH="${CONFIG_REPO_PATH:-config/litellm_config.yaml}"

if [ -n "$CONFIG_REPO_URL" ]; then
    echo "Fetching config from $CONFIG_REPO_URL (branch: $CONFIG_REPO_BRANCH)..."
    if [ -d "$CONFIG_REPO_DIR/.git" ]; then
        cd "$CONFIG_REPO_DIR"
        git fetch origin "$CONFIG_REPO_BRANCH" --depth 1 2>/dev/null
        git reset --hard "origin/$CONFIG_REPO_BRANCH" 2>/dev/null
        cd /
    else
        rm -rf "$CONFIG_REPO_DIR"
        git clone --depth 1 --branch "$CONFIG_REPO_BRANCH" "$CONFIG_REPO_URL" "$CONFIG_REPO_DIR" 2>/dev/null
    fi

    if [ -f "$CONFIG_REPO_DIR/$CONFIG_REPO_PATH" ]; then
        cp "$CONFIG_REPO_DIR/$CONFIG_REPO_PATH" "$CONFIG_DIR/litellm_config.yaml"
        chown ${USERNAME}:${USERNAME} "$CONFIG_DIR/litellm_config.yaml"
        echo "Config updated from repo"
    else
        echo "WARNING: $CONFIG_REPO_PATH not found in repo, using baked-in config"
    fi
else
    echo "No CONFIG_REPO_URL set, using baked-in config"
fi

# Start LiteLLM proxy in the background as the user
echo "Starting LiteLLM proxy on port 4000..."
su - ${USERNAME} -c "$USER_HOME/.config/litellm/start-litellm.sh" &

# Keep container running (SSH accessible even if LiteLLM crashes)
echo "Container ready. SSH: port 22, LiteLLM: port 4000"
tail -f /dev/null
