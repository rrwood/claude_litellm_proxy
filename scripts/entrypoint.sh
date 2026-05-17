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
    echo "IMPORTANT: Configure your Google API key"
    echo "================================================"
    echo "Edit: ~/.config/litellm/.env"
    echo "Get API key: https://aistudio.google.com/app/apikey"
    echo ""
fi

# Start LiteLLM proxy in the background as the user
echo "Starting LiteLLM proxy on port 4000..."
su - ${USERNAME} -c "$USER_HOME/.config/litellm/start-litellm.sh" &

# Keep container running (SSH accessible even if LiteLLM crashes)
echo "Container ready. SSH: port 22, LiteLLM: port 4000"
tail -f /dev/null
