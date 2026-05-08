#!/bin/bash
#
# Welcome Message - LiteLLM Proxy Container
# Displayed on login
#

cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║       Welcome to LiteLLM Proxy Container! 🚀                  ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

📋 LiteLLM Configuration

   🔐 1. Configure Google API Key:
      nano ~/.config/litellm/.env

      Add: GOOGLE_API_KEY=your_actual_key_here
      Get key: https://aistudio.google.com/app/apikey

   📝 2. Configuration files:
      ~/.config/litellm/.env              - API keys
      ~/.config/litellm/litellm_config.yaml - Model mappings

🔍 Check LiteLLM Status

   • Health check:
     curl http://localhost:4000/health

   • List models:
     curl http://localhost:4000/v1/models \
       -H "Authorization: Bearer DUMMY_KEY"

   • Test chat completion:
     curl http://localhost:4000/v1/chat/completions \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer DUMMY_KEY" \
       -d '{
         "model": "claude-sonnet-4-5-20250929",
         "messages": [{"role": "user", "content": "Hello"}],
         "max_tokens": 50
       }'

   • Check logs:
     ps aux | grep litellm

🛠️  Manage LiteLLM

   • Restart LiteLLM:
     pkill -f litellm
     ~/.config/litellm/start-litellm.sh &

   • Edit config:
     nano ~/.config/litellm/litellm_config.yaml

📚 Documentation

   • GitHub: https://github.com/rrwood/claude_litellm_proxy
   • LiteLLM: https://docs.litellm.ai/

───────────────────────────────────────────────────────────────

EOF
