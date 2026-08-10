#!/bin/bash
export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"
CONFIG_DIR="$HOME/.config/litellm"

# Source .env file but don't override vars already set (e.g. from docker-compose/Portainer)
if [ -f "$CONFIG_DIR/.env" ]; then
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        key=$(echo "$key" | xargs)
        if [ -z "${!key}" ]; then
            export "$key=$value"
        fi
    done < "$CONFIG_DIR/.env"
fi

litellm --config "$CONFIG_DIR/litellm_config.yaml" --port 4000 --host 0.0.0.0
