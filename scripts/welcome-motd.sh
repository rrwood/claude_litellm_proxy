#!/bin/bash
#
# Welcome Message - LiteLLM Proxy Container
# Displayed on login
#

cat << 'EOF'

========================================================
  LiteLLM Proxy Container
========================================================

  Configuration
  -------------
  1. Set your NVIDIA NIM API key:
     nano ~/.config/litellm/.env
     Get key: https://build.nvidia.com/nim

  2. Config files:
     ~/.config/litellm/.env              - API keys
     ~/.config/litellm/litellm_config.yaml - Model mappings

  Quick Commands
  --------------
  Health check:   curl http://localhost:4000/health
  List models:    curl http://localhost:4000/v1/models \
                    -H "Authorization: Bearer DUMMY_KEY"
  Restart:        pkill -f litellm && \
                    ~/.config/litellm/start-litellm.sh &
  View config:    cat ~/.config/litellm/litellm_config.yaml

  Docs: https://docs.litellm.ai/
--------------------------------------------------------

EOF
