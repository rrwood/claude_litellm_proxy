#!/bin/bash
CONFIG_DIR="$HOME/.config/litellm"

# Auto-export all environment variables
set -a
source "$CONFIG_DIR/.env"
set +a

litellm --config "$CONFIG_DIR/litellm_config.yaml" --port 4000 --host 0.0.0.0
