# Claude LiteLLM Proxy

**Use Claude Code CLI with free Gemini models via LiteLLM proxy**

A Docker container that runs a LiteLLM proxy, allowing Claude Code CLI to use Google's free Gemini API instead of paid Claude API credits. All Claude model requests are automatically translated to Gemini 2.5 Flash.

## Why Use This?

- **Free**: Use Google's generous Gemini free tier instead of paying for Claude API
- **Drop-in replacement**: Claude Code CLI works exactly the same, just point it to this proxy
- **Centralized**: Run one proxy server, connect multiple Claude Code clients
- **Simple**: Pre-configured and ready to deploy

## Features

- **LiteLLM Proxy** with Anthropic-compatible API
- **Auto-start** LiteLLM on container boot
- **SSH access** for configuration and troubleshooting
- **Model mapping** - All Claude models → Gemini 2.5 Flash
- **Docker-based** - Easy deployment with Docker Compose or Portainer

## Example Deployment

One proxy server can serve multiple Claude Code clients across different platforms and use cases:

```
                           ┌─────────────────────────────────┐
                           │   Docker Server (Portainer)     │
                           │                                 │
                           │  ┌───────────────────────────┐  │
    ┌──────────────────────┼─►│  LiteLLM Proxy Container  │  │
    │                      │  │  (192.168.1.100:4000)     │──┼──► Google Gemini API
    │                      │  │                           │  │    (Free Tier)
    │                      │  │  • Deployed via GitHub    │  │
    │                      │  │  • Auto-start on boot     │  │
    │  Claude Code CLI     │  └───────────────────────────┘  │
    │  Clients             │                                 │
    │                      └─────────────────────────────────┘
    │
    │  ┌────────────────────────────────────────┐
    ├──┤  Windows Desktop                       │
    │  │  • Claude Code CLI                     │
    │  │  • VS Code extension                   │
    │  │  • General development                 │
    │  └────────────────────────────────────────┘
    │
    │  ┌────────────────────────────────────────┐
    ├──┤  Linux Laptop                          │
    │  │  • Claude Code CLI                     │
    │  │  • Terminal-based development          │
    │  └────────────────────────────────────────┘
    │
    │  ┌────────────────────────────────────────┐
    └──┤  Home Assistant OS                     │
       │  ┌──────────────────────────────────┐  │
       │  │  Dev Container (Docker)          │  │
       │  │  • Claude Code CLI               │  │
       │  │  • Home Assistant development    │  │
       │  └──────────────────────────────────┘  │
       └────────────────────────────────────────┘
```

**Benefits of this setup:**
- ✅ Single Google API key shared across all devices
- ✅ Consistent model access from any machine
- ✅ Easy to manage (update config once, affects all clients)
- ✅ Works with containerized development environments
- ✅ No API keys stored on client machines

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- A network with static IP capability (or use bridge networking)
- Google API key from https://aistudio.google.com/app/apikey (free)

### 1. Clone and Configure

```bash
git clone https://github.com/rrwood/claude_litellm_proxy.git
cd claude_litellm_proxy

# Copy and edit environment file
cp .env.example .env
nano .env  # Update network settings for your environment
```

### 2. Deploy

```bash
docker-compose up -d
```

### 3. Configure Google API Key

SSH into the container:
```bash
ssh litellm@YOUR_CONTAINER_IP
# Default password: changeme123 (change this!)
```

Edit the API key:
```bash
nano ~/.config/litellm/.env
# Add your Google API key
```

Restart the container:
```bash
docker-compose restart
```

### 4. Configure Claude Code Clients

On your client machine (Windows/Linux/Mac), set environment variables:

**Windows (PowerShell):**
```powershell
$env:ANTHROPIC_BASE_URL="http://YOUR_CONTAINER_IP:4000"
$env:ANTHROPIC_API_KEY="DUMMY_KEY"
```

**Linux/Mac (Bash):**
```bash
export ANTHROPIC_BASE_URL=http://YOUR_CONTAINER_IP:4000
export ANTHROPIC_API_KEY=DUMMY_KEY
```

Then run:
```bash
claude /logout  # Logout of claude.ai first
claude          # Start using the proxy!
```

See [CLIENT_SETUP.md](CLIENT_SETUP.md) for detailed client configuration.

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Fast deployment guide
- **[CLIENT_SETUP.md](CLIENT_SETUP.md)** - Configure Claude Code clients
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

## Configuration

### Network Settings

The default `docker-compose.yml` uses macvlan networking for direct network access. Update `.env` with your network settings:

- `CONTAINER_IP` - Static IP for the container
- `NETWORK_SUBNET` - Your network subnet (e.g., 192.168.1.0/24)
- `NETWORK_GATEWAY` - Your network gateway
- `NETWORK_INTERFACE` - Host interface (e.g., eth0)

### Using Bridge Networking (Alternative)

If you don't have static IP capability, use bridge networking with port mapping. See [BRIDGE_NETWORKING.md](BRIDGE_NETWORKING.md).

### Security

**Change the default password immediately:**

```bash
ssh litellm@YOUR_CONTAINER_IP
passwd
```

Or set `USER_PASSWORD` in `.env` before deploying.

## Available Models

The proxy maps these Claude models to Gemini 2.5 Flash:
- `claude-opus-4-7` → `gemini-2.5-flash`
- `claude-sonnet-4-5-20250929` → `gemini-2.5-flash`
- `claude-haiku-4-5-20251001` → `gemini-2.5-flash`

You can also request `gemini-2.5-flash` directly.

## Limitations

- **Free tier only**: Uses Gemini 2.5 Flash (free). For Gemini Pro, upgrade your Google API plan.
- **Rate limits**: Subject to Google's free tier rate limits (see https://ai.google.dev/pricing)
- **Model differences**: Gemini 2.5 Flash is not identical to Claude models

## How It Works

```
Claude Code CLI → LiteLLM Proxy → Google Gemini API
                  (translates Anthropic API → Gemini API)
```

LiteLLM acts as a proxy that:
1. Receives requests in Anthropic's API format
2. Translates them to Google's Gemini API format
3. Sends responses back in Anthropic's format

## Contributing

Issues and pull requests welcome!

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- [LiteLLM](https://github.com/BerriAI/litellm) - The proxy powering this project
- [Google Gemini](https://ai.google.dev/) - Free AI API
- [Anthropic Claude](https://claude.ai/) - Claude Code CLI

## Support

For issues and questions:
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Open an issue on GitHub
- Visit LiteLLM docs: https://docs.litellm.ai/
