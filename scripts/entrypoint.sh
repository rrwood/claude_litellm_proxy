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

# Fetch config from remote URL if CONFIG_REPO_URL is set
if [ -n "${CONFIG_REPO_URL:-}" ]; then
    echo "Fetching config from: $CONFIG_REPO_URL"
    if curl -fsSL "$CONFIG_REPO_URL" -o "$USER_HOME/.config/litellm/litellm_config.yaml.tmp"; then
        mv "$USER_HOME/.config/litellm/litellm_config.yaml.tmp" "$USER_HOME/.config/litellm/litellm_config.yaml"
        chown ${USERNAME}:${USERNAME} "$USER_HOME/.config/litellm/litellm_config.yaml"
        echo "Config updated from remote URL"
    else
        rm -f "$USER_HOME/.config/litellm/litellm_config.yaml.tmp"
        echo "WARN: Config fetch failed, using existing config"
    fi
fi

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

# Start LiteLLM proxy in the background as the user
echo "Starting LiteLLM proxy on port 4000..."
su - ${USERNAME} -c "$USER_HOME/.config/litellm/start-litellm.sh" &

# Keep container running (SSH accessible even if LiteLLM crashes)
echo "Container ready. SSH: port 22, LiteLLM: port 4000"
tail -f /dev/null
