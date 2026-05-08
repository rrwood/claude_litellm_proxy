#!/bin/bash
set -e

# Start SSH service
sudo /usr/sbin/sshd

# Check if .env file exists, if not create from example
if [ ! -f "$HOME/.config/litellm/.env" ]; then
    cp "$HOME/.config/litellm/.env.example" "$HOME/.config/litellm/.env"
    echo "================================================"
    echo "IMPORTANT: Configure your Google API key"
    echo "================================================"
    echo "Edit: ~/.config/litellm/.env"
    echo "Get API key: https://aistudio.google.com/app/apikey"
    echo ""
fi

# Start LiteLLM proxy
echo "Starting LiteLLM proxy on port 4000..."
exec "$HOME/.config/litellm/start-litellm.sh"
